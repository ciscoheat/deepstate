package ds.gen;

import haxe.DynamicAccess;
import ds.*;
import ds.internal.MetaObjectType;
import haxe.macro.Expr;
import DeepState as Ds;

class DeepState<T> {
    public final state : T;

    @:allow(DeepStateContainer)
    final middlewares : ImmutableArray<Middleware<T>>;

    // All state types created by the build macro
    @:noCompletion final stateTypes : Map<String, MetaObjectType>;

    // Current state type
    @:noCompletion final stateType : MetaObjectType;

    public function new(
        initialState : T,
        stateTypes : Map<String, MetaObjectType>, 
        stateType : MetaObjectType, 
        middlewares : ImmutableArray<Middleware<T>>
    ) {
        if(initialState == null) throw "initialState is null";
        this.state = initialState;
        this.stateTypes = stateTypes;
        this.stateType = stateType;
        this.middlewares = middlewares == null ? [] : middlewares;
    }

    /////////////////////////////////////////////////////////////////

    /**
     * Updates the asset
     * @param asset 
     * @param args 
     */
    public macro function update(asset : Expr, args : Array<Expr>) {
        return Ds._update(asset, args);
    }

    @:allow(DeepStateContainer)
    function copy(newState : T = null, middlewares : ImmutableArray<Middleware<T>> = null) : DeepState<T> {
        // Automatically done in DeepStateInfrastructure
        throw "DeepStateBase.copy must be overridden in subclass.";
    }

    /**
     * Make a copy of a state object, replacing a value in the state.
     * All references except the new value will be kept.
     */
    @:noCompletion inline function _createAndReplace(currentState : T, path : ImmutableArray<Action.PathAccess>, newValue : Any) : T {
        function error() { throw "Invalid DeepState update: " + path + " (" + newValue + ")"; }

        var iter = path.iterator();
        function createNew(currentObject : Any, curState : MetaObjectType) : Any {
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
                        return createNew(currentObject, this.stateType);

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
            return this.copy(newState, this.middlewares);
        }

        // Apply middleware
        var dispatch : Action -> DeepState<T> = copyAndUpdateState;
        for(m in middlewares.reverse())
            dispatch = m.bind(this, dispatch);

        return cast dispatch(action);
    }
}
