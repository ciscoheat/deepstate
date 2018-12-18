package ds.internal;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.DynamicAccess;
import ds.ImmutableArray;
import ds.internal.MetaObjectType;

using Lambda;
using haxe.macro.TypeTools;
using haxe.macro.MacroStringTools;
using haxe.macro.ExprTools;

/**
 * A macro build class for checking that the state type is final,
 * and creating a path => type state structure for quick access.
 */
class DeepStateInfrastructure {

    static function metaMapToExpr(fields : Map<String, MetaObjectType>) {
        var values = [for(key in fields.keys()) {
            //trace("----- " + key + " => " + fields[key]);
            if(fields[key] != null)
                macro $v{key} => ${metaToExpr(fields[key])};
        }];
        return {
            expr: EArrayDecl(values),
            pos: Context.currentPos()
        }
    }

    static function metaToExpr(meta : MetaObjectType) : Expr {
        return switch meta {
            case Bool: macro Bool;
            case String: macro String;
            case Int: macro Int;
            case Int32: macro Int32;
            case Int64: macro Int64;
            case Float: macro Float;
            case Date: macro Date;
            case Enumm: macro Enumm;
            case ImmutableList: macro ImmutableList;
            case ImmutableJson: macro ImmutableJson;
            case Recursive(type): macro Recursive($v{type});
            case Anonymous(fields): macro Anonymous(${metaMapToExpr(fields)});
            case Instance(cls, fields): macro Instance($v{cls}, ${metaMapToExpr(fields)});
            case Array(type): macro Array(${metaToExpr(type)});
            case Map(type): macro Map(${metaToExpr(type)});
        }
    }

    /*
    static function defaultState(meta : MetaObjectType) : Expr {
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
            //case Map(_): []; // RC5 feature
            case Array(_): macro [];
            case Recursive(_): macro null;
            case Anonymous(fields): mapToAnon(fields);
            case Instance(cls, _):
                macro throw "Non-supported default value: " + $v{cls};
            case _:
                macro throw "Non-supported default value: " + $v{Std.string(meta)};
        }
    }
    */

    static public function genericBuild() {
        var checkedTypes = new RecursiveTypeCheck();
        var isRecursive = false;

        function stateFieldType(type : Type) : MetaObjectType {
            //trace([for(key in checkedTypes.keys()) key]);

            return switch type {
                case TEnum(t, params):
                    var enumType = t.get();
                    if(checkedTypes.exists(enumType)) {
                        isRecursive = true;
                        Recursive(checkedTypes.key(enumType));
                    }
                    else {
                        // Check immutability
                        for(p in params) stateFieldType(p);
                        for(c in enumType.constructs) {
                            switch c.type {
                                case TFun(args, _): for(a in args) stateFieldType(a.t);
                                case _: Context.error("Expected enum constructor", Context.currentPos());
                            }
                            for(p in c.params) stateFieldType(p.t);
                        }
                        for(p in enumType.params) stateFieldType(p.t);

                        checkedTypes.mark(enumType);
                        Enumm;
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
                    var isTypeParam = switch type.kind {
                        case KTypeParameter(_): true;
                        case _: false;
                    }

                    switch [type.pack, type.name] {
                        case [[], "String"]: String;
                        case [[], "Date"]: Date;
                        case [[], "Array"] | [[], "List"]:
                            Context.error('State contains a mutable ${type.name}. Use ds.Immutable${type.name} instead.', Context.currentPos());
                        case [["haxe"], "IMap"]: 
                            Context.error('State contains a mutable Map. Use ds.ImmutableMap instead.', Context.currentPos());
                        case _:
                            if(checkedTypes.exists(type)) {
                                isRecursive = true;
                                Recursive(checkedTypes.key(type));
                            }
                            else {
                                if(!isTypeParam)
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
                                var inst = Instance(clsName, fields);
                                //trace("TInst: " + clsName);

                                if(!isTypeParam) checkedTypes.set(type, inst)
                                else inst;
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
                        case [["ds"], "ImmutableMap"]: Map(stateFieldType(params[1]));
                        case [["ds"], "ImmutableArray"]: Array(stateFieldType(params[0]));
                        case _:
                            //trace("TAbstract: " + abstractType.type);
                            stateFieldType(Context.followWithAbstracts(abstractType.type));
                    }

                case TType(t, params):
                    var typede = t.get();
                    //trace("TType: " + typede.name);

                    for(p in params) stateFieldType(p);
                    for(p in typede.params) stateFieldType(p.t);

                    return if(checkedTypes.exists(typede)) {
                        isRecursive = true;
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

        //trace("--- Checkedtypes: " + [for(key in checkedTypes.keys()) key]);

        var stateType = switch Context.getLocalType() {
            // Let the compiler infer generic type parameters.
            case TInst(_, [t]): 
                switch t {
                    case TInst(ref, params): switch ref.get().kind {
                        case KTypeParameter(_): return null;
                        case _:
                    }
                    case TType(ref, params):

                    case TAnonymous(a):
                        Context.error("Create a typedef of this anonymous type, to use it in DeepState.", Context.currentPos());

                    case x: 
                        Context.error("Invalid state type: " + x, Context.currentPos());
                }
                t;

            case _:
                Context.error("DeepState<T> class expected.", Context.currentPos());
        }
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
        var clsName = "DeepState_" + StringTools.replace(stateTypeName, ".", "_");

        // Test if type is defined already
        try {
            var type = Context.getType(clsName);
            return Context.toComplexType(type);
        } catch(e : String) {}

        ///////////////////////////////////////////////////

        var stateTypeMeta = stateFieldType(stateType);
        var stateComplexType = Context.toComplexType(stateType);

        //trace("===== " + cls.name + " " + stateType);
        //trace(Context.currentPos());
        //trace(stateComplexType); trace(clsName);

        var typePath = { name: clsName, pack: [] }
        var concreteType = TPath(typePath);
        var metaMap = checkedTypes.map();

        // Remove redundant keys if state isn't recursive.
        /*
        if(!isRecursive) {
            for(key in metaMap.keys()) if(key != stateTypeName) {
                metaMap.remove(key);
            }
        }
        */

            //static final _defaultState : $stateComplexType = ${defaultState(checkedTypes.getStr(stateTypeName))};
        var c = macro class $clsName extends ds.gen.DeepState<$stateComplexType> {
            static final _stateTypes : Map<String, ds.internal.MetaObjectType> = ${metaMapToExpr(metaMap)};

            public function new(
                initialState : $stateComplexType,
                middlewares : ds.ImmutableArray<ds.Middleware<$stateComplexType>> = null
            ) {
                super(initialState, _stateTypes, _stateTypes.get($v{stateTypeName}), middlewares);
            }

            /*
            public macro function update(asset : haxe.macro.Expr, args : Array<haxe.macro.Expr>) {
                return ds.internal.DeepStateUpdate._update(asset, args);
            }
            */

            public function updateState(action : ds.Action) : $concreteType
                return cast(this._updateState(action), $concreteType);

            override function copy(
                newState : $stateComplexType = null, 
                middlewares : ds.ImmutableArray<ds.Middleware<$stateComplexType>> = null
            ) : $concreteType {
                return new $typePath(
                    newState == null ? this.state : newState, 
                    middlewares == null ? this.middlewares : middlewares
                );
            }
        }
        c.meta.push({name: ":final", pos: c.pos});

        Context.defineType(c);
        return concreteType;
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
        //trace('--Marking $typeName');
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