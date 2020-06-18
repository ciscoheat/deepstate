package ds.gen;

import haxe.DynamicAccess;
import ds.*;
#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import ds.internal.DeepStateUpdate as Ds;
#end

class DeepState<T> {
    public final state : T;

    @:allow(ds.MiddlewareAccess)
    final middlewares : ImmutableArray<Middleware<T>>;

    // All state types created by the build macro
    @:allow(ds.MiddlewareAccess)
    @:noCompletion final stateTypes : Map<String, StateObjectType>;

    // Current state type
    @:allow(ds.MiddlewareAccess)
    @:noCompletion final stateType : StateObjectType;

    public function new(
        state : T,
        stateTypes : Map<String, StateObjectType>, 
        stateType : StateObjectType, 
        middlewares : ImmutableArray<Middleware<T>>
    ) {
        this.state = state == null ? throw "state is null" : state;
        this.stateTypes = stateTypes == null ? throw "stateTypes is null" : stateTypes;
        this.stateType = stateType == null ? throw "stateType is null" : stateType;
        this.middlewares = middlewares == null ? [] : middlewares;
    }

    ///// Public interface //////////////////////////////////////////

    public macro function update(asset : Expr, args : Array<Expr>) {
        return Ds._update(asset, args);
    }

    ///// Protected /////////////////////////////////////////////////

    @:allow(ds.MiddlewareAccess)
    function copyAsset(newState : T = null, middlewares : ImmutableArray<Middleware<T>> = null) : DeepState<T> {
        // Automatically done in DeepStateInfrastructure
        throw "DeepState.copyAsset must be overridden in subclass.";
    }

    ///// Private /////////////////////////////////////////////////

    /**
     * Make a copy of a state object, replacing a value in the state.
     * All references except the new value will be kept.
     */
    @:noCompletion inline function _createAndReplace(currentState : T, path : ImmutableArray<Action.PathAccess>, newValue : Null<Any>) : T {
        function error() { throw "Invalid DeepState update: " + path + " (" + @:nullSafety(Off) newValue + ")"; }

        var iter = path.iterator();
        function createNew(currentObject : Any, curState : StateObjectType) : Null<Any> {
            //trace(currentObject + " - " + curState);
            if(!iter.hasNext()) return newValue
            else switch iter.next() {
                case Field(name): switch curState {
                    case Anonymous(fields):
                        var data = Reflect.copy(currentObject);
                        if(data == null) return null;

                        var field = fields.get(name);
                        if(field == null) error() else {
                            var newObj = createNew(Reflect.field(currentObject, name), field);
                            @:nullSafety(Off) Reflect.setField(data, name, newObj);
                        }
                        return data;

                    case Instance(cls, fields):
                        // Create a new class with data constructor
                        var data = new haxe.DynamicAccess<Dynamic>();

                        // If problems, use getProperty instead of field.
                        for(f in fields.keys())
                            data.set(f, Reflect.field(currentObject, f));

                        var field = fields.get(name);
                        if(field == null) error()
                        else @:nullSafety(Off) data.set(name, createNew(Reflect.field(currentObject, name), field));

                        return Type.createInstance(Type.resolveClass(cls), [data]);

                    case Recursive(type):
                        var curState = this.stateTypes.get(type);
                        if(curState == null) error() else
                        return createNew(currentObject, curState);

                    case _: error();
                }
                case Array(index): switch curState {
                    case Array(type):
                        var newArray = (currentObject : Array<Dynamic>).copy();
                        @:nullSafety(Off) newArray[index] = createNew(newArray[index], type);
                        return newArray;

                    case _: error();
                }
                case Map(key): switch curState {
                    case Map(type):
                        var currentMap : ImmutableMap<Dynamic, Dynamic> = cast currentObject;
                        var currentObj = currentMap.get(key);
                        if(currentObj == null) error()
                        else @:nullSafety(Off) return currentMap.set(key, createNew(currentObj, type));

                    case _: error();
                }

            }
            
            error();
            throw "_createAndReplace error";
        }

        var newObj = createNew(currentState, this.stateType);
        if(newObj == null) error();
        @:nullSafety(Off) return newObj;
    }

    @:allow(DeepStateContainer) @:noCompletion 
    function _updateState<S : DeepState<T>>(action : Action) : S {
        // Last function in middleware chain - create a new state.
        function copyAndUpdateState(action : Action) : DeepState<T> {
            var newState = this.state;
            for(a in action.updates) {
                @:nullSafety(Off) newState = _createAndReplace(newState, a.path, a.value);
            }
            return this.copyAsset(newState, this.middlewares);
        }

        // Apply middleware
        var dispatch : Action -> DeepState<T> = copyAndUpdateState;
        for(m in middlewares.reverse())
            dispatch = m.bind(this, dispatch);

        return cast dispatch(action);
    }
}
