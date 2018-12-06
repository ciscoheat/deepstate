import ds.*;
import haxe.macro.Expr;

class DeepStateContainer<S : DeepState<S,T>,T> {
    #if !macro
    var asset(default, null) : S;
    final observable : ds.Observable<S, T>;

    public var state(get, never) : T;
    function get_state() : T return asset.state;

    public function new(asset : S, middlewares : ImmutableArray<Middleware<S,T>> = null, observable : Observable<S,T> = null) {
        if(asset == null) throw "asset is null";
        if(observable == null) observable = new Observable<S, T>();

        if(middlewares == null) middlewares = []; 
        middlewares = middlewares.concat([updateAsset, observable.observe]);

        this.observable = observable;
        this.asset = asset.copy(asset.state, middlewares);
    }

    function updateAsset(asset, next, action) {
        return this.asset = next(action);
    }

    @:noCompletion public function subscribeObserver(observer: Observer<T>, immediateCall : Null<T> = null) : Subscription {
        return this.observable.subscribeObserver(observer, immediateCall);
    }

    @:noCompletion public function updateState(action : Action) : Void {
        this.asset.updateState(action);
    }

    #end

    public macro function update(container : ExprOf<DeepStateContainer>, args : Array<Expr>) {
        return DeepState._update(container, args);
    }

    public macro function subscribe(container : ExprOf<DeepStateContainer>, paths : Array<Expr>) {
        return Observable._subscribe(container, paths);
    }
}
