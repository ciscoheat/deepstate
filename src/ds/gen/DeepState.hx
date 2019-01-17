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
        this.stateTypes = stateTypes;
        this.stateType = stateType;
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
    @:noCompletion inline function _createAndReplace(currentState : T, path : ImmutableArray<Action.PathAccess>, newValue : Any) : T {
        function error() { throw "Invalid DeepState update: " + path + " (" + newValue + ")"; }

        var iter = path.iterator();
        function createNew(currentObject : Any, curState : StateObjectType) : Any {
            //trace(currentObject + " - " + curState);
            if(!iter.hasNext()) return newValue
            else switch iter.next() {
                case Field(name): switch curState {
                    case Anonymous(fields):
                        var data = Reflect.copy(currentObject);
                        Reflect.setField(data, name, createNew(Reflect.field(currentObject, name), fields.get(name)));
                        return data;

                    case Instance(cls, fields):
                        // Create a new class with data constructor
                        var data = new haxe.DynamicAccess<Dynamic>();

                        // If problems, use getProperty instead of field.
                        for(f in fields.keys())
                            data.set(f, Reflect.field(currentObject, f));

                        data.set(name, createNew(Reflect.field(currentObject, name), fields.get(name)));

                        return Type.createInstance(Type.resolveClass(cls), [data]);

                    case Recursive(type):
                        return createNew(currentObject, this.stateTypes.get(type));

                    case _: error();
                }
                case Array(index): switch curState {
                    case Array(type):
                        var newArray = (currentObject : Array<Dynamic>).copy();
                        newArray[index] = createNew(newArray[index], type);
                        return newArray;

                    case _: error();
                }
                case Map(key): switch curState {
                    case Map(type):
                        var currentMap : ImmutableMap<Dynamic, Dynamic> = cast currentObject;
                        return currentMap.set(key, createNew(currentMap.get(key), type));

                    case _: error();
                }

            }
            // TODO: Throw here
            return null;
        }

        return createNew(currentState, this.stateType);
    }

    @:allow(DeepStateContainer) @:noCompletion 
    function _updateState<S : DeepState<T>>(action : Action) : S {
        // Last function in middleware chain - create a new state.
        function copyAndUpdateState(action : Action) : DeepState<T> {
            var newState = this.state;
            for(a in action.updates) {
                newState = _createAndReplace(newState, a.path, a.value);
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
