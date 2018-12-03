import ds.Action.PathAccess;
import haxe.Unserializer;
import haxe.DynamicAccess;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.Constraints;
import ds.*;

using Reflect;
using Lambda;

#if macro
using haxe.macro.Tools;
using haxe.macro.TypeTools;

// Intermediary enum, used to test for duplicate actions before
// transforming it to to Action.
private enum PathAccessExpr {
    Field(name : String);
    Array(e : Expr);
}

private typedef ActionUpdateExpr = {
    var path : Array<PathAccessExpr>;
    var value : Expr;
}
#end

/**
 * Used for describing the state tree and its types.
 */
enum MetaObjectType {
    Basic;
    Enum;
    Recursive(type : String);
    Anonymous(fields: Map<String, MetaObjectType>);
    Instance(cls: String, fields: Map<String, MetaObjectType>);
    Array(type: MetaObjectType); // Always an ImmutableArray
}

/////////////////////////////////////////////////////////////////////

@:autoBuild(ds.internal.DeepStateInfrastructure.build())
class DeepState<S : DeepState<S,T>, T> {
    #if !macro

    // All state types T created by the build macro
    @:noCompletion public static var stateTypes : Map<String, MetaObjectType>
        = cast haxe.Unserializer.run(haxe.rtti.Meta.getType(DeepState).stateTypes[0]);

    // Automatically overridden in inherited classes by build macro
    @:noCompletion function stateType() : MetaObjectType { return null; }

    public final state : T;
    final middlewares : ImmutableArray<Middleware<S,T>>;

    function new(currentState : T, middlewares : ImmutableArray<Middleware<S,T>> = null) {
        if(currentState == null) throw "currentState is null";

        this.state = currentState;
        this.middlewares = middlewares == null ? [] : middlewares;
    }

    /////////////////////////////////////////////////////////////////

    // Override if you create an inherited constructor.
    function copy(newState : T) : S {
        return cast Type.createInstance(Type.getClass(this), [newState, this.middlewares]);
    }

    // Make a deep copy of a new state object.
    @:noCompletion function createAndReplace(currentState : T, path : ImmutableArray<Action.PathAccess>, newValue : Any) : T {
        function error() { throw "Invalid DeepState update: " + path + " (" + newValue + ")"; }

        var iter = path.iterator();
        function createNew(currentObject : Any, curState : MetaObjectType) : Any {
            //trace(currentObject + " - " + curState);
            if(!iter.hasNext()) return newValue
            else switch iter.next() {
                case Field(name): switch curState {
                    case Anonymous(fields):
                        //trace("Creating Anonymous");
                        var data = Reflect.copy(currentObject);
                        Reflect.setField(data, name, createNew(Reflect.field(currentObject, name), fields.get(name)));
                        return data;

                    case Instance(cls, fields):
                        //trace("Creating Instance");
                        // Create a new class with data constructor
                        var data = new haxe.DynamicAccess<Dynamic>();

                        // If problems, use getProperty instead of field.
                        for(f in fields.keys())
                            data.set(f, Reflect.field(currentObject, f));

                        data.set(name, createNew(Reflect.field(currentObject, name), fields.get(name)));

                        return Type.createInstance(Type.resolveClass(cls), [data]);

                    case Recursive(type):
                        //throw "Deep recursive updates not supported. Update the topmost recursive field only in type " + type.substr(1);
                        return createNew(currentObject, stateTypes.get(type));

                    case _: error();
                }
                case Array(index): switch curState {
                    case Array(type):
                        var newArray = (currentObject : Array<Dynamic>).copy();
                        newArray[index] = createNew(newArray[index], type);
                        return newArray;

                    case _: error();
                }

            }
            return null;
        }

        return createNew(currentState, this.stateType());
    }

    @:noCompletion public function updateState(action : Action) : S {
        /*
        for(u in action.updates) {
            var path = [for(p in u.path) switch p {
                case Field(name): name;
                case Array(index): Std.string(index);
            }].join(".");
            trace('[${action.type}] ' + path + " => " + u.value);
        }
        */

        // Last function in middleware chain - create a new state.
        function copyAndUpdateState(action : Action) : S {
            var newState = this.state;
            //trace("BEFORE ================== " + newState);
            for(a in action.updates) {
                newState = createAndReplace(newState, a.path, a.value);
            }
            /*
            trace("AFTER ================== " + newState);
            trace(newState);
            trace("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
            */
            return this.copy(newState);
        }

        // Apply middleware
        var dispatch : Action -> S = copyAndUpdateState;

            for(m in middlewares.reverse()) {
            dispatch = m.bind(cast this, dispatch);
        }

        return dispatch(action);
    }

    @:noCompletion function getFieldInState(state : T, path : String) {
        if(path == "") return state;

        var output : Dynamic = state;
        for(p in path.split(".")) {
            if(!Reflect.hasField(output, p)) throw 'Field not found in state: $path';
            output = Reflect.field(output, p);
        }
        return output;
    }
    #else

      ////////////////////////////////////////////////////////////////
     //// Macro code ////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////

    static function unifies(type : ComplexType, value : Expr) return try {
        // Test if types unify by trying to assign a temp var with the new value
        Context.typeof(macro var _DStest : $type = $value);
        true;
    } catch(e : Dynamic) false;

    static function _updateField(path : Expr, pathType : haxe.macro.Type, newValue : Expr) : ActionUpdateExpr {
        return if(!unifies(Context.toComplexType(pathType), newValue)) {
            Context.error("Value should be of type " + pathType.toString(), newValue.pos);
        } else {
            var filterPath = true;
            var paths = new Array<PathAccessExpr>();
            function parseUpdateExpr(e : Expr) switch e.expr {
                case EField(e1, name): 
                    if(name == "state") filterPath = false
                    else if(filterPath) paths.push(Field(name));
                    parseUpdateExpr(e1);
                case EArray(e1, e2):
                    paths.push(Array(e2));
                    parseUpdateExpr(e1);
                case EConst(CIdent(name)):
                    if(name == "state") filterPath = false 
                    else if(filterPath) paths.push(Field(name));
                case x:
                    Context.error("Invalid DeepState update expression.", e.pos);
            }
            parseUpdateExpr(path);
            paths.reverse();

            { 
                path: paths,
                value: newValue
            }
        }
    }

    /////////////////////////////////////////////////////////////////

    static function _updateFunc(path : Expr, pathType : haxe.macro.Type, newValue : Expr) {
        return switch newValue.expr {
            case EFunction(name, f) if(f.args.length == 1):
                f.ret = f.args[0].type = Context.toComplexType(pathType);
                var funcCall = {
                    expr: ECall(newValue, [path]),
                    pos: newValue.pos
                }
                _updateField(path, pathType, funcCall);
            case x:
                Context.error('Function must take an argument of type $pathType and return the same.', newValue.pos);
        }
    }

    static function _updatePartial(path : Expr, pathType : haxe.macro.Type, fields : Array<ObjectField>) {
        return [for(f in fields) {
            var fieldName = f.field;
            var fieldPath = macro $path.$fieldName;

            var fieldType = try Context.typeof(fieldPath)
            catch(e : Dynamic) {
                Context.error("Cannot determine field type, try providing a type hint.", f.expr.pos);
            }

            _updateField(fieldPath, fieldType, f.expr);
        }];
    }

    static function _updateIn(path : Expr, newValue : Expr) {
        var pathType = try Context.typeof(path)
        catch(e : Dynamic) {
            Context.error("Cannot find field or its type in state.", path.pos);
        }

        return switch newValue.expr {
            case EObjectDecl(fields) if(!unifies(Context.toComplexType(pathType), newValue)): 
                // Update with a partial object
                _updatePartial(path, pathType, fields);

            case EFunction(name, f):
                // Update with a function/lambda expression 
                [_updateFunc(path, pathType, newValue)];
            
            case _: 
                // Update any other value
                [_updateField(path, pathType, newValue)];
        }
    }

    /////////////////////////////////////////////////////////////////

    static var typeNameCalls = new Map<String, {hash: String, pos: haxe.macro.Position}>();
    static function checkDuplicateAction(store : Expr, actionType : String, updates : Array<ActionUpdateExpr>, pos) {

        var clsName = try switch Context.typeof(store) {
            case TInst(t, _):
                var cls = t.get();
                cls.module + "." + cls.pack.join(".") + "." + cls.name + ".";
            case _:
                Context.error("Asset is not a class.", store.pos);
        } catch(e : Dynamic) {
            Context.error("Asset type not found, please provide a type hint.", store.pos);
        }

        var updateHash = [for(u in updates) {
            [for(p in u.path) switch p {
                case Field(name): name;
                case Array(e): "()";
            }].join(".");
        }];
        updateHash.sort((a,b) -> a < b ? -1 : 1);

        //trace(updateHash);

        var hashKey = clsName + actionType;
        var actionHash = ' => [' + updateHash.join("] [") + ']';

        if(typeNameCalls.exists(hashKey)) {
            var typeHash = typeNameCalls.get(hashKey);

            if(typeHash.hash != actionHash) {
                var msg = 'Duplicate action type "$actionType", change updates or action type name.';
                Context.warning(msg, typeHash.pos);
                Context.error(msg, pos);
            }
        }
        else {
            #if deepstate_list_actions
            Context.warning('$actionType$actionHash', pos);
            #end
            typeNameCalls.set(hashKey, {hash: actionHash, pos: pos});
        }
    }

    #end

    public macro function update(store : ExprOf<DeepState<Dynamic>>, args : Array<Expr>) {
        var actionType : Expr = null;

        // Extract Action updates from the parameters
        var updates = switch args[0].expr {
            case EArrayDecl(values): 
                actionType = args[1];

                values.flatMap(e -> {
                    switch e.expr {
                        case EBinop(op, e1, e2) if(op == OpArrow):
                            _updateIn(e1, e2);
                        case _: 
                            Context.error("Parameter must be an array map declaration: [K => V, ...]", e.pos);
                            null;
                    }
                }).array();
            
            case _: 
                actionType = args[2];
                _updateIn(args[0], args[1]);
        }

        // Set a default action type (Class.method) if not specified
        var aTypeString : String;
        var aTypePos : Position;

        function defaultType(pos) {
            aTypeString = Context.getLocalClass().get().name + "." + Context.getLocalMethod();
            aTypePos = pos;
            return macro $v{aTypeString};
        }

        var aType = if(actionType == null) defaultType(Context.currentPos()) else switch actionType.expr {
            case EConst(CIdent("null")):
                defaultType(actionType.pos);
            case EConst(CString(s)):
                aTypeString = s;
                aTypePos = actionType.pos;
                actionType;
            case _:
                actionType;
        }

        checkDuplicateAction(store, aTypeString, updates, aTypePos);

        // Display mode and vshaxe diagnostics have some problems with this.
        //if(Context.defined("display") || Context.defined("display-details")) 
            //return macro null;

        return {
            var realUpdates = [for(u in updates) {
                var paths = [for(p in u.path) switch p {
                    case Field(name): macro ds.PathAccess.Field($v{name});
                    case Array(e): macro ds.PathAccess.Array($e);
                }];

                macro {
                    path: $a{paths},
                    value: ${u.value}
                }
            }];

            macro $store.updateState({
                type: $aType,
                updates: $a{realUpdates}
            });
        }
    }
}
