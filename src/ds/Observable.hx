package ds;

import haxe.macro.Context;
import haxe.macro.Expr;

using Reflect;
using Lambda;

class Observable<T> {
    final observers : Array<Observer<T>>;

    public function new() {
        this.observers = [];
    }

    @:noCompletion public function subscribeObserver(observer: Observer<T>, immediateCall : Null<T> = null) : Subscription {
        observers.push(observer);
        if(immediateCall != null) {
            observeState(observer, immediateCall, immediateCall, true);
        }
        return new Subscription(function() observers.remove(observer));
    }

    public function observe(state: T, next : Action -> T, action : Action) : T {
        var newState = next(action);
        for(o in observers) observeState(o, state, newState);
        return newState;
    }

    function observeState(l : Observer<T>, previousState : T, newState : T, shouldCall = false) : Void {
        function getFieldInState(state : T, path : String) {
            if(path == "") return state;

            var output : Dynamic = state;
            for(p in path.split(".")) {
                if(!Reflect.hasField(output, p)) throw 'Field not found in state: $path';
                output = Reflect.field(output, p);
            }
            return output;
        }

        switch l {
            case Full(listener):
                listener(previousState, newState);
            case Partial(paths, listener):
                var parameters : Array<Dynamic> = [];

                for(path in paths) {
                    var prevValue = if(shouldCall) null else getFieldInState(previousState, path);
                    var currentValue = getFieldInState(newState, path);
                    shouldCall = shouldCall || prevValue != currentValue;
                    parameters.push(currentValue);
                }

                if(shouldCall)
                    Reflect.callMethod(null, listener, parameters);
        }        
    }

    public macro function subscribe(observable : ExprOf<Observable<S,T>>, paths : Array<Expr>) {
        var listener = paths.pop();

        var callImmediate = switch listener.expr {
            case EFunction(_, _): macro null;
            case _:
                if(paths.length == 0) macro null
                else {
                    // Last argument = bool
                    var currentState = listener;
                    listener = paths.pop();
                    currentState;
                }
        }

        return if(paths.length == 0) {
            // Full state listener
            switch listener.expr {
                case EFunction(_, f) if(f.args.length == 2):
                    macro $observable.subscribeObserver(ds.Observer.Full($listener), $callImmediate);
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
                        var path = DeepState.stripPathPrefix(p);
                        {
                            expr: EConst(CString(path)),
                            pos: p.pos
                        }
                    });

                    macro $observable.subscribeObserver(ds.Observer.Partial($a{stringPaths}, $listener), $callImmediate);
                case x:
                    Context.error('Function must take the same number of arguments as specified fields.', listener.pos);
            }
        }
    }
}
