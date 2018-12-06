package ds.internal;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.DynamicAccess;
import ds.ImmutableArray;
import DeepState.MetaObjectType;

using Lambda;
using haxe.macro.TypeTools;
using haxe.macro.MacroStringTools;
using haxe.macro.ExprTools;

/**
 * A macro build class for checking that the state type is final,
 * and creating a path => type statec structure for quick access.
 */
class DeepStateInfrastructure {
    static var checkedTypes : RecursiveTypeCheck;

    static public function build() {
        if(checkedTypes == null) {
            checkedTypes = new RecursiveTypeCheck();
            Context.onGenerate(types -> {
                for(t in types) switch t {
                    case TInst(t, params):
                        var inst = t.get();
                        if(inst.pack.length == 0 && inst.name == "DeepState") {
                            var serialized = haxe.Serializer.run(checkedTypes.map());
                            inst.meta.add("stateTypes", [macro $v{serialized}], Context.currentPos());
                        }
                    case _:
                }
            });
        }

        function stateFieldType(type : Type) : MetaObjectType {
            return switch type {
                case TEnum(t, params):
                    var enumType = t.get();
                    if(checkedTypes.exists(enumType)) 
                        Recursive(checkedTypes.key(enumType))
                    else {
                        checkedTypes.mark(enumType);
                        Enum;
                    }

                case TAnonymous(a):
                    var fields = new Map<String, MetaObjectType>();
                    for(field in a.get().fields) switch field.kind {
                        case FVar(read, write) if(write == AccNever || write == AccCtor):
                            fields.set(field.name, stateFieldType(field.type));
                        case _:
                            Context.error('Field is not final, cannot be used in DeepState.', field.pos);
                    }
                    //trace("TAnonymous: " + [for(key in fields.keys()) key]);
                    Anonymous(fields);

                case TInst(t, _):
                    var type = t.get();

                    switch [type.pack, type.name] {
                        case [[], "String"]: String;
                        case [[], "Date"]: Date;
                        case [[], "Array"] | [[], "List"]:
                            Context.error('State contains a mutable ${type.name}. Use ds.Immutable${type.name} instead.', Context.currentPos());
                        case [["haxe"], "IMap"]: 
                            Context.error('State contains a mutable Map. Use ds.ImmutableMap instead.', Context.currentPos());
                        case _:
                            if(checkedTypes.exists(type)) 
                                Recursive(checkedTypes.key(type))
                            else {
                                checkedTypes.mark(type);

                                var fields = new Map<String, MetaObjectType>();
                                for(field in type.fields.get()) switch field.kind {
                                    case FVar(_, write):
                                        if(write == AccNever || write == AccCtor)
                                            fields.set(field.name, stateFieldType(field.type));
                                        else
                                            Context.error('Field is not final, cannot be used in DeepState.', field.pos);
                                    case _:
                                }
                                
                                var clsName = haxe.macro.MacroStringTools.toDotPath(type.pack, type.name);
                                //trace("TInst: " + clsName);
                                checkedTypes.set(type, Instance(clsName, fields));
                            }
                        }

                case TAbstract(t, params):
                    var abstractType = t.get();

                    switch [abstractType.pack, abstractType.name] { 
                        case [[], "Bool"]: Bool;
                        case [[], "Float"]: Float;
                        case [[], "Int"]: Int;
                        case [["haxe"], "Int32"]: Int32;
                        case [["haxe"], "Int64"]: Int64;
                        case [["ds"], "ImmutableJson"]: ImmutableJson;
                        case [["ds"], "ImmutableList"]: ImmutableList;
                        case [["ds"], "ImmutableMap"]: ImmutableMap;
                        case [["ds"], "ImmutableArray"]: Array(stateFieldType(params[0]));
                        case _:
                            //trace("TAbstract: " + abstractType.type);
                            stateFieldType(Context.followWithAbstracts(abstractType.type));
                    }

                case TType(t, params):
                    var typede = t.get();
                    //trace("TType: " + typede.name);
                    return if(checkedTypes.exists(typede)) {
                        Recursive(checkedTypes.key(typede));
                    }
                    else {
                        checkedTypes.mark(typede);
                        var recType = stateFieldType(typede.type);
                        checkedTypes.set(typede, recType);
                    }

                case TLazy(f):
                    stateFieldType(f());

                case x:
                    Context.error('Unsupported DeepState type: $x', Context.currentPos());
            }
        }

        /////////////////////////////////////////////////////////////

        var cls = Context.getLocalClass().get();

        var stateType = cls.superClass.params[1];
        var stateTypeMeta = stateFieldType(stateType);
        var stateTypeName = switch stateType {
            case TType(t, _):
                var t = t.get();
                t.pack.toDotPath(t.name);
            case TInst(t, _):
                var t = t.get();
                t.pack.toDotPath(t.name);
            case TEnum(t, _):
                var t = t.get();
                t.pack.toDotPath(t.name);
            case TAnonymous(_):
                Context.error("Create a typedef of the state type, to use it in DeepState.", Context.currentPos());
            case x:
                Context.error("Invalid state type: " + x, Context.currentPos());
        }        

        // Add a constructor if not defined
        var fields = Context.getBuildFields();
        if(!fields.exists(f -> f.name == "new")) {
            fields.push({
                access: [APublic],
                kind: FFun({
                    args: [
                        {name: 'currentState', type: null},
                        {name: 'middlewares', type: null, opt: true}
                    ],
                    expr: macro super(currentState, middlewares),
                    ret: null
                }),
                name: "new",
                pos: Context.currentPos()
            });
        }
        else if(!fields.exists(f -> f.name == "copy")) {
            Context.warning(
                "'copy' method not overridden despite inherited constructor.", 
                fields.find(f -> f.name == "new").pos
            );
        }

        fields.push({
            access: [AOverride],
            doc: "Internal function for accessing the state type.",
            kind: FieldType.FFun({ 
                args: [],
                expr: macro return DeepState.stateTypes.get($v{stateTypeName}),
                ret: macro : DeepState.MetaObjectType
            }),
            name: "stateType",
            meta: [{
                name: ":noCompletion", params: null, pos: Context.currentPos()
            }],
            pos: Context.currentPos()
        });

        ///// Add a default function /////

        function defaultState(meta : MetaObjectType) : Expr {
            function mapToAnon(fields : Map<String, MetaObjectType>) {
                var values = [for(key in fields.keys()) {
                    field: key,
                    expr: defaultState(fields[key])
                }];
                return {
                    expr: EObjectDecl(values),
                    pos: Context.currentPos()
                }
            }

            return switch meta {
                case Bool: macro false;
                case String: macro "";
                case Int: macro 0;
                case Int64: macro haxe.Int64.make(0,0);
                case Float: macro 0.0;
                case Date: macro Date.now();
                case ImmutableJson: macro new haxe.DynamicAccess<Dynamic>();
                //case ImmutableMap: macro []; // RC5 feature
                case Array(_): macro [];
                case Recursive(_): macro null;
                case Anonymous(fields): mapToAnon(fields);
                case Instance(cls, _):
                    macro throw "Non-supported default value: " + $v{cls};
                case _:
                    macro throw "Non-supported default value: " + $v{Std.string(meta)};
            }
        }

        fields.push({
            access: [AStatic, APublic],
            doc: "Returns a default state, that can be used to create a new asset. Will throw if some values cannot be created.",
            kind: FieldType.FFun({ 
                args: [],
                expr: macro return ${defaultState(stateTypeMeta)},
                ret: Context.toComplexType(stateType)
            }),
            name: "defaultState",
            meta: [{
                name: ":noCompletion", params: null, pos: Context.currentPos()
            }],
            pos: Context.currentPos()
        });

        return fields;
    }
}

/////////////////////////////////////////////////////////////////////

/*
class ContainerInfrastructure {
    static public function build() {
        var cls = Context.getLocalClass().get();

        var assetType = cls.superClass.params[0];


        // Add a constructor if not defined
        var fields = Context.getBuildFields();

        if(fields.exists(f -> f.name == "new")) return null;

        fields.push({
            access: [APublic],
            kind: FFun({
                args: [
                    {name: 'asset', type: null},
                    {name: 'middlewares', type: null, opt: true},
                    {name: 'observable', type: null, opt: true}
                ],
                expr: macro {
                    super(asset, middlewares, observable);
                },
                ret: null
            }),
            name: "new",
            pos: Context.currentPos()
        });

        return fields;
    }
}
*/

/////////////////////////////////////////////////////////////////////

@:forward(keys)
abstract RecursiveTypeCheck(Map<String, Null<MetaObjectType>>) {
    inline public function new() 
        this = new Map<String, Null<MetaObjectType>>();

    public function get(t : {pack : Array<String>, name: String}) {
        var typeName = key(t);
        return this.get(typeName);
    }

    public function getStr(key : String) {
        return this.get(key);
    }

    public function exists(t : {pack : Array<String>, name: String}) {
        var typeName = key(t);
        return this.exists(typeName);
    }

    public function mark(t : {pack : Array<String>, name: String}) {
        var typeName = key(t);
        if(this.exists(typeName)) throw "Checked type exists: " + typeName;

        this.set(typeName, null);
    }

    public function set(t : {pack : Array<String>, name: String}, type : MetaObjectType) {
        var typeName = key(t);
        if(type == null) throw "MetaObjectType is null.";
        if(this.exists(typeName) && this.get(typeName) != null) throw "Checked type wasn't null: " + typeName;

        this.set(typeName, type);
        return type;
    }

    public function key(t : {pack : Array<String>, name: String}) {
        return t.pack.toDotPath(t.name);
    }

    public function map() return this;
}

#end