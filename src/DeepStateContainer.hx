import ds.*;
import haxe.macro.Expr;

//@:genericBuild
class DeepStateContainer {
    #if !macro
    var asset(default, null) : AgeNameAsset;
    final observable : ds.Observable<AgeNameAsset, AgeName>;

    public var state(get, never) : AgeName;
    function get_state() : AgeName return asset.state;

    public function new(asset : AgeNameAsset, middlewares : ImmutableArray<Middleware<AgeNameAsset,AgeName>> = null, observable : Observable<AgeNameAsset,AgeName> = null) {
        if(observable == null) observable = new Observable<AgeNameAsset, AgeName>();

        if(middlewares == null) middlewares = []; 
        middlewares = middlewares.concat([updateAsset, observable.observe]);

        this.observable = observable;
        this.asset = asset.copy(asset.state, middlewares);
    }

    function updateAsset(asset, next, action) {
        return this.asset = next(action);
    }

    @:noCompletion public function subscribeObserver(observer: Observer<AgeName>, immediateCall : Null<AgeName> = null) : Subscription {
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

#if !macro
typedef AgeName = {
	final age : Int;
	final name : String;
}

class AgeNameAsset extends DeepState<AgeNameAsset, AgeName> {}
#end