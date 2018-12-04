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
                    
                    if(type.pack.length == 0 && type.name == "String") 
                        Basic
                    else if(type.pack.length == 0 && type.name == "Date") 
                        Basic
                    else if(type.pack.length == 0 && type.name == "Array")
                        Context.error('State contains a mutable Array. Use ds.ImmutableArray instead.', Context.currentPos());
                    else if(type.pack.length == 0 && type.name == "List")
                        Context.error('State contains a mutable List. Use ds.ImmutableList instead.', Context.currentPos());
                    else if(type.pack.length == 1 && type.pack[0] == "haxe" && type.name == "IMap")
                        Context.error('State contains a mutable Map. Use ds.ImmutableMap instead.', Context.currentPos());
                    else {
                        if(checkedTypes.exists(type)) 
                            Recursive(checkedTypes.key(type))
                        else {
                            checkedTypes.mark(type);

                            var fields = new Map<String, MetaObjectType>();
                            for(field in type.fields.get()) switch field.kind {
                                case FVar(read, write):
                                    if(field.isFinal)
                                        fields.set(field.name, stateFieldType(field.type));
                                    else
                                        Context.error('Field is not final, cannot be used in DeepState.', field.pos);
                                case FMethod(_):
                            }
                            
                            var clsName = haxe.macro.MacroStringTools.toDotPath(type.pack, type.name);
                            //trace("TInst: " + clsName);
                            checkedTypes.set(type, Instance(clsName, fields));
                        }
                    }

                case TAbstract(t, params):
                    var abstractType = t.get();

                    if(abstractType.pack.length == 0 && ( 
                        abstractType.name == "Bool" || 
                        abstractType.name == "Float" ||
                        abstractType.name == "Int"
                    )) { 
                        Basic;
                    }
                    else if(abstractType.pack[0] == "haxe" && abstractType.name == "Int64") 
                        Basic
                    else if(abstractType.pack[0] == "ds" && abstractType.name == "ImmutableJson")
                        Basic
                    else if(abstractType.pack[0] == "ds" && (
                        abstractType.name == "ImmutableList" ||
                        abstractType.name == "ImmutableMap"
                    )) {
                        Basic;
                    }
                    else if(abstractType.pack[0] == "ds" && abstractType.name == "ImmutableArray") {
                        //trace("Array: " + params[0]);
                        Array(stateFieldType(params[0]));
                    }
                    else {
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
            case x:
                Context.error("Invalid state type: " + x, Context.currentPos());
        }

        // Add a constructor if not defined
        var fields = Context.getBuildFields();
        if(!fields.exists(f -> f.name == "new")) {
            if(cls.superClass.t.get().name == "ObservableDeepState")
                fields.push({
                    access: [APublic],
                    kind: FFun({
                        args: [
                            {name: 'currentState', type: null},
                            {name: 'middlewares', type: null, opt: true},
                            {name: 'observable', type: null, opt: true}
                        ],
                        expr: macro super(currentState, middlewares),
                        ret: null
                    }),
                    name: "new",
                    pos: Context.currentPos()
                })
            else // Normal DeepState
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

        // Add the stateType map
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

        return fields;
    }
}

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