import haxe.DynamicAccess;
import haxe.macro.Context;
import haxe.macro.Expr;
import ds.*;

#if macro
using haxe.macro.Tools;
using haxe.macro.TypeTools;
#end

using Reflect;
using Lambda;

@:autoBuild(ds.internal.DeepStateInfrastructure.build())
class DeepState<T> {
    #if !macro
    static final allStateObjects = new Map<String, Map<String, {cls: Class<Dynamic>, fields: Array<String>}>>();

    public var state(default, null) : T;

    final middlewares : ImmutableArray<Middleware<T>>;
    final listeners : Array<Subscription<T>>;
    final stateObjects : Map<String, {cls: Class<Dynamic>, fields: Array<String>}>;

    function new(initialState : T, middlewares : ImmutableArray<Middleware<T>> = null) {
        this.state = initialState;
        this.middlewares = middlewares == null ? [] : middlewares.reverse();
        this.listeners = [];

        // Restore metadata, that will be used to create a new state object.
        var cls = Type.getClass(this);
        var name = Type.getClassName(cls);

        this.stateObjects = if(allStateObjects.exists(name))
            allStateObjects.get(name)
        else {
            var map = new Map<String, {cls: Class<Dynamic>, fields: Array<String>}>();
            var metadata = haxe.rtti.Meta.getType(cls).field("stateObjects")[0];
            
            for(key in Reflect.fields(metadata)) {
                var o : DynamicAccess<Dynamic> = Reflect.field(metadata, key);
                map.set(key, {
                    cls: Type.resolveClass(o.get('cls')),
                    fields: o.get('fields')
                });
            }

            allStateObjects.set(name, map);
            map;
        }
    }

    @:noCompletion public function subscribe(subscription: Subscription<T>, immediateCall = false) : Void -> Void {
        listeners.push(subscription);
        if(immediateCall) {
            callListener(subscription, this.state, this.state, immediateCall);
        }
        return function() listeners.remove(subscription);
    }

    /////////////////////////////////////////////////////////////////

    // Make a deep copy of a new state object.
    function createAndReplace(currentState : T, path : ImmutableArray<String>, newValue : Any) : T {
        if(path[0] != "") path = path.unshift("");

        var currentObj = currentState;
        var chain = [];
        for(i in 0...path.length-1) {
            chain.push({
                currentObj: currentObj,
                fullPath: i == 0 ? '' : path.slice(1,i+1).join('.'),
                field: path[i+1]
            });
            currentObj = currentObj.getProperty(path[i+1]);
        };
        chain.reverse();

        //trace('========='); trace('$path -> $newValue'); trace(chain);

        // Create a new object based on the current one, replacing a single field,
        // representing a state path.
        function createNew(currentObj : Any, fullPath : String, field : String, newValue : Any) : Any {
            return if(!stateObjects.exists(fullPath)) {
                // Anonymous structure
                var data = Reflect.copy(currentObj);

                if(!data.hasField(field))
                    throw 'Field not found in state: $fullPath';

                Reflect.setField(data, field, newValue);
                data;
            } else {
                // Class instantiation
                var metadata = stateObjects.get(fullPath);
                var data = new haxe.DynamicAccess<Dynamic>();

                if(!metadata.fields.has(field))
                    throw 'Field not found in state: $fullPath';

                // If problems, use getProperty instead of field.
                for(f in metadata.fields) 
                    data.set(f, Reflect.field(currentObj, f));

                data.set(field, newValue);

                Type.createInstance(metadata.cls, [data]);
            }
        }

        var newValue : Dynamic = newValue;
        for(c in chain)
            newValue = createNew(c.currentObj, c.fullPath, c.field, newValue);

        return cast newValue;
    }

    @:noCompletion public function updateState(action : Action) : T {
        // Last function in middleware chain - create a new state.
        function copyAndUpdateState(action : Action) : T {
            var newState = this.state;
            for(a in action.updates) {
                newState = createAndReplace(newState, a.path.split("."), a.value);
            }
            return newState;
        }

        // Save for listeners
        var listeners = this.listeners.copy();
        var previousState = this.state;

        // Apply middleware
        var newState = {
            var dispatch : Action -> T = copyAndUpdateState;

            for(m in this.middlewares) {
                dispatch = m.bind(this.state, dispatch);
            }

            // Set final state for this update
            dispatch(action);
        }

        // Change state
        this.state = newState;

        // Notify subscribers
        for(l in listeners)
            callListener(l, previousState, newState);

        return newState;
    }

    function getFieldInState(state : T, path : String) {
        if(path == "") return state;

        var output : Dynamic = state;
        for(p in path.split(".")) {
            if(!Reflect.hasField(output, p)) throw 'Field not found in state: $path';
            output = Reflect.field(output, p);
        }
        return output;
    }

    function callListener(l : Subscription<T>, previousState : T, newState : T, shouldCall = false) : Void {
        switch l {
            case Full(listener):
                listener(previousState, newState);
            case Partial(paths, listener):
                var parameters : Array<Dynamic> = [];

                for(path in paths) {
                    // TODO: Ignore value changes, always call if in path?
                    var prevValue = if(shouldCall) null else getFieldInState(previousState, path);
                    var currentValue = getFieldInState(newState, path);
                    shouldCall = shouldCall || prevValue != currentValue;
                    parameters.push(currentValue);
                }

                if(shouldCall)
                    Reflect.callMethod(null, listener, parameters);
        }        
    }

    #end

    #if macro
    static function unifies(type : ComplexType, value : Expr) return try {
        // Test if types unify by trying to assign a temp var with the new value
        Context.typeof(macro var _DStest : $type = $value);
        true;
    } catch(e : Dynamic) false;

    static function stripPathPrefix(path : Expr) : String {
        // Strip "asset.state" from path
        var pathStr = path.toString();
        return if(pathStr == "state" || pathStr.lastIndexOf(".state") == pathStr.length-6) 
            ""
        else {
            var index = pathStr.indexOf("state.");
            index == -1 ? pathStr : pathStr.substr(index + 6);
        }
    }

    static function _updateField(path : Expr, pathType : haxe.macro.Type, newValue : Expr) {
        return if(!unifies(Context.toComplexType(pathType), newValue)) {
            Context.error("Value should be of type " + pathType.toString(), newValue.pos);
        } else {
            [macro {
                path: $v{stripPathPrefix(path)},
                value: $newValue
            }];
        }
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

            if(!unifies(Context.toComplexType(fieldType), f.expr)) {
                Context.error("Value should be of type " + fieldType.toString(), f.expr.pos);
            }

            var strippedPath = stripPathPrefix(fieldPath);

            // Create the update
            macro {
                path: $v{strippedPath},
                value: ${f.expr}
            }
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
                _updateFunc(path, pathType, newValue);
            
            case _: 
                // Update any other value
                _updateField(path, pathType, newValue);
        }
    }

    static function createAction(store : ExprOf<DeepState<Dynamic>>, actionType : Null<ExprOf<String>>, updates : Array<Expr>) : Expr {
        var aType = actionType == null 
            ? macro $v{Context.getLocalClass().get().name + "." + Context.getLocalMethod()}
            : actionType;

		// Display mode and vshaxe diagnostics have some problems with this.
		//if(Context.defined("display") || Context.defined("display-details")) 
			//return macro null;

        return macro $store.updateState({
            type: $aType,
            updates: $a{updates}
        });
    }    
    #end

    public macro function subscribeTo(store : ExprOf<DeepState<Dynamic>>, paths : Array<Expr>) {
        var listener = paths.pop();

        var callImmediate = switch listener.expr {
            case EFunction(_, _): macro false;
            case _:
                if(paths.length == 0) macro false
                else {
                    // Last argument = bool
                    var boolTest = listener;
                    listener = paths.pop();
                    boolTest;
                }
        }

        return if(paths.length == 0) {
            // Full state listener
            switch listener.expr {
                case EFunction(_, f) if(f.args.length == 2):
                    macro $store.subscribe(ds.Subscription.Full($listener), $callImmediate);
                case x:
                    Context.error('Argument must be a function that takes two arguments, previous and next state.', listener.pos);
            }
        } else {
            // Partial listener
            var pathTypes = [for(p in paths) {
                try Context.typeof(p)
                catch(e : Dynamic) {
                    Context.error("Cannot find field or its type in state.", p.pos);
                }
            }];

            switch listener.expr {
                case EFunction(_, f) if(f.args.length == paths.length):
                    for(i in 0...paths.length)
                        f.args[i].type = Context.toComplexType(pathTypes[i]);

                    var stringPaths = paths.map(p -> {
                        var path = stripPathPrefix(p);
                        {
                            expr: EConst(CString(path)),
                            pos: p.pos
                        }
                    });

                    macro $store.subscribe(ds.Subscription.Partial($a{stringPaths}, $listener), $callImmediate);
                case x:
                    Context.error('Function must take the same number of arguments as specified fields.', listener.pos);
            }
        }
    }

    public macro function updateIn(store : ExprOf<DeepState<Dynamic>>, args : Array<Expr>) {
        var actionType : Expr = null;

        var updates = switch args[0].expr {
            case EArrayDecl(values): 
                if(args.length == 2) actionType = args[1];
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
                if(args.length == 3) actionType = args[2];
                _updateIn(args[0], args[1]);
        }

        return createAction(store, actionType, updates);
    }
}
