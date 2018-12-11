import ds.*;
import haxe.macro.Expr;

class DeepStateContainer<T> {
    #if !macro
    var asset(default, null) : DeepState<T>;
    final observable : ds.Observable<T>;

    public var state(get, never) : T;
    function get_state() : T return asset.state;

    public function new(asset : DeepState<T>, middlewares : ImmutableArray<Middleware<T>> = null, observable : Observable<T> = null) {
        if(asset == null) throw "asset is null";
        if(observable == null) observable = new Observable<T>();

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

    public macro function update(container : Expr, args : Array<Expr>) {
        return DeepState._update(container, args);
    }

    public macro function subscribe(container : Expr, paths : Array<Expr>) {
        return Observable._subscribe(container, paths);
    }
}
