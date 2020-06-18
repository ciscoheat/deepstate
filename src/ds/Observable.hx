package ds;

import haxe.macro.Context;
import haxe.macro.Expr;

using Reflect;
using haxe.macro.ExprTools;

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

    public function observe(asset : Dynamic, next : Action -> Dynamic, action : Action) : Dynamic {
        var newState = next(action);
        for(o in observers) observeState(o, asset.state, newState.state);
        return newState;
    }

    function observeState(observer : Observer<T>, previousState : T, newState : T, shouldCall = false) : Void {
        function getFieldInState(state : T, path : String) {
            if(path == "") return state;

            var output : Dynamic = state;
            for(p in path.split(".")) {
                if(!Reflect.hasField(output, p)) throw 'Field not found in state: $path';
                @:nullSafety(Off) output = Reflect.field(output, p);
            }
            return output;
        }

        switch observer {
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
                    @:nullSafety(Off) Reflect.callMethod(null, listener, parameters);
        }        
    }

    public macro function subscribe(observable : Expr, paths : Array<Expr>) {
        return _subscribe(observable, paths);
    }

    #if macro
    public static function _subscribe(observable : Expr, paths : Array<Expr>) {
        // Make an array of the arguments to use them in the returned expression, 
        // otherwise autocompletion doesn't work in the macro function call.
        if(Context.defined("display") || Context.defined("display-details")) {
            return macro $a{paths};
        }

        var listener = paths.pop();

        var callImmediate = switch listener.expr {
            case EFunction(_, _): macro null;
            case _:
                if(paths.length == 0) macro null
                else {
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
                        var path = p.toString();
                        if(path.indexOf("[") >= 0)
                            Context.error("Cannot subscribe to array access", p.pos);

                        {
                            expr: EConst(CString(~/^.*state\.?/.replace(path, ''))),
                            pos: p.pos
                        }
                    });

                    macro $observable.subscribeObserver(ds.Observer.Partial($a{stringPaths}, $listener), $callImmediate);
                case x:
                    Context.error('Function must take the same number of arguments as specified fields.', listener.pos);
            }
        }
    }
    #end
}
