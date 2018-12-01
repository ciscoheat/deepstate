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
#end

/////////////////////////////////////////////////////////////////////

enum MetaObjectType {
    Basic;
    Enum;
    Anonymous(fields: Map<String, MetaObjectType>);
    Instance(cls: String, fields: Map<String, MetaObjectType>);
    Array(type: MetaObjectType);
}

#if macro
typedef ActionUpdate = {
    path: Array<{field: String, index: Expr}>,
    value: Expr
}
#else
private typedef ClassMetaData = {cls: Class<Dynamic>, fields: Array<String>};

// Data transformed from an Action
private enum StateUpdate {
    Anonymous(currentObj : DynamicAccess<Dynamic>, field : StateField);
    Instance(metadata : ClassMetaData, currentObj : Any, field : StateField);
    Array(array : Array<Dynamic>, index : Int, type : StateUpdate);
}

private enum StateField {
    Anonymous(field : String);
    Instance(/*metadata : ClassMetaData,*/ field : String);
    Array(index : Int, field : String);
}
#end

@:autoBuild(ds.internal.DeepStateInfrastructure.build())
class DeepState<S : DeepState<S,T>, T> {
    #if !macro
    public final state : T;
    final middlewares : ImmutableArray<Middleware<S,T>>;
    final stateType : MetaObjectType;

    function new(currentState : T, stateType : MetaObjectType, middlewares : ImmutableArray<Middleware<S,T>> = null) {
        this.state = currentState;
        this.stateType = stateType;
        this.middlewares = middlewares == null ? [] : middlewares;
    }

    /////////////////////////////////////////////////////////////////

    function copy(newState : T) : S {
        return cast Type.createInstance(Type.getClass(this), [newState, this.middlewares]);
    }

    // Make a deep copy of a new state object.
    @:noCompletion function createAndReplace(currentState : T, path : Array<{field: String, index: Null<Int>}>, newValue : Any) : T {
        if(path.length == 0 || path[0].field != "") path.unshift({field: "", index: null});

        var currentObj = currentState;
        var chain = [];
        for(i in 0...path.length-1) {
            var fullPath = i == 0 ? '' : path.slice(1,i+1).map(p -> p.field).join('.');
            var currentType = path[i];
            var fieldType = path[i+1];

            trace(fullPath);

            /*
            var fieldState = if(fieldType.index != null)
                StateField.Array(fieldType.index, fieldType.field);
            else if(stateObjects.exists(fullPath))
                StateField.Instance(fieldType.field);
            else
                StateField.Anonymous(fieldType.field);

            function createStateUpdate(path : String) {

            }
            var currentState = if(currentType.index != null)
                StateUpdate.Array(cast currentObj, currentType.index, fieldState);
            else if(stateObjects.exists(fullPath))
                StateUpdate.Instance(stateObjects.get(fullPath), currentObj, fieldState);
            else
                StateUpdate.Anonymous(cast currentObj, fieldState);

            chain.push(currentState);
            currentObj = currentObj.getProperty(fieldType.field);
            */
        };
        chain.reverse();

        //trace('========='); trace('${path.join(".")} -> $newValue'); trace(chain.map(c -> { fullPath: c.fullPath, field: c.field }));

        // Create a new object based on the current one, replacing a single field,
        // representing a state path.
        function createNew(update : StateUpdate, newValue : Any) : Any {

            function newFieldValue(currentObj : Any, field : StateField) : {field: String, value: Any} {
                /*
                return switch field {
                    case Anynomous(name): 
                        {field: name, value: newValue};
                    case Instance(metadata, name): 

                    case Array(index, name):
                        var array : Array<Dynamic> = Reflect.field(currentObj, name);
                        var newArray = array.array();
                        newArray[index] = newValue;
                        {field: name, value: cast newValue};
                }
                */
                return null;
            }

            return switch update {
                case Anonymous(currentObj, field):
                    // Create a new anonymous structure
                    var update = newFieldValue(currentObj, field);
                    if(!currentObj.exists(update.field)) 
                        throw 'Field not found in state: ${update.field}';

                    var data = Reflect.copy(currentObj);
                    Reflect.setField(data, update.field, update.value);
                    data;

                case Instance(metadata, currentObj, field):
                    // Create a new class with data constructor
                    var data = new haxe.DynamicAccess<Dynamic>();

                    var update = newFieldValue(currentObj, field);
                    if(!metadata.fields.has(update.field))
                        throw 'Field not found in state: ${update.field}';

                    // If problems, use getProperty instead of field.
                    for(f in metadata.fields) 
                        data.set(f, Reflect.field(currentObj, f));

                    data.set(update.field, update.value);

                    Type.createInstance(metadata.cls, [data]);

                case Array(array, index, field):
                    // Create a new object in an array
                    var newArray = array.copy();
                    newArray;
            }
        }

        var newValue : Dynamic = newValue;
        for(update in chain) newValue = createNew(update, newValue);

        return cast newValue;
    }

    @:noCompletion public function updateState(action : Action) : S {
        //for(u in action.updates) for(p in u.path) trace(p.field + (p.index != null ? ' [${p.index}]' : ''));

        // Last function in middleware chain - create a new state.
        function copyAndUpdateState(action : Action) : S {
            var newState = this.state;
            for(a in action.updates) {
                newState = createAndReplace(newState, a.path, a.value);
            }
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

    ///// Macro code ////////////////////////////////////////////////

    static function unifies(type : ComplexType, value : Expr) return try {
        // Test if types unify by trying to assign a temp var with the new value
        Context.typeof(macro var _DStest : $type = $value);
        true;
    } catch(e : Dynamic) false;

    public static function createActionUpdate(path : Expr, value : Expr) : ActionUpdate {
        var paths = new Array<{field: String, index: Expr}>();
        function buildPath(p : Expr, param : Expr) switch p.expr {
            case EField(e, field):
                paths.unshift({field: field, index: param});
                buildPath(e, macro null);
            case EArray(e1, e2):
                buildPath(e1, e2);
            case EConst(CIdent(s)):
                paths.unshift({field: s, index: param});
            case _:
                Context.error("Invalid: " + p.expr, p.pos);
        }
        buildPath(path, macro null);

        while(paths[0].field != "state") paths.shift();
        paths.shift();
        //trace(paths);

        return { 
            path: paths,
            value: value
        }
    }

    static function _updateField(path : Expr, pathType : haxe.macro.Type, newValue : Expr) : ActionUpdate {
        return if(!unifies(Context.toComplexType(pathType), newValue)) {
            Context.error("Value should be of type " + pathType.toString(), newValue.pos);
        } else
            createActionUpdate(path, newValue);
    }

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

    static var typeNameCalls = new Map<String, {hash: String, pos: haxe.macro.Position}>();
    static function checkDuplicateAction(store : Expr, actionType : String, updates : Array<ActionUpdate>, pos) {

        var clsName = try switch Context.typeof(store) {
            case TInst(t, _):
                var cls = t.get();
                cls.module + "." + cls.pack.join(".") + "." + cls.name + ".";
            case _:
                Context.error("Asset is not a class.", store.pos);
        } catch(e : Dynamic) {
            Context.error("Asset type not found, please provide a type hint.", store.pos);
        }

        var hashKey = clsName + actionType;
        var updateHash = ' => [' + updates.map(u -> u.path).join("] [") + ']';

        if(typeNameCalls.exists(hashKey)) {
            var typeHash = typeNameCalls.get(hashKey);

            if(typeHash.hash != updateHash) {
                var msg = 'Duplicate action type "$actionType", change updates or action type name.';
                Context.warning(msg, typeHash.pos);
                Context.error(msg, pos);
            }
        }
        else {
            #if deepstate_list_actions
            Context.warning('$actionType$updateHash', pos);
            #end
            typeNameCalls.set(hashKey, {hash: updateHash, pos: pos});
        }
    }

    static function createAction(
        store : ExprOf<DeepState<Dynamic,Dynamic>>, 
        actionType : Null<ExprOf<String>>, 
        updates : Array<ActionUpdate>
    ) : Expr {

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

        var macroUpdates = updates.map(u -> macro {
            path: $a{u.path.map(p -> macro {
                field: $v{p.field},
                index: ${p.index}
            })},
            value: ${u.value}
        });

        return macro $store.updateState({
            type: $aType,
            updates: $a{macroUpdates}
        });
    }    
    #end

    public macro function update(store : ExprOf<DeepState<Dynamic>>, args : Array<Expr>) {
        var actionType : Expr = null;

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

        return createAction(store, actionType, updates);
    }
}
