import ds.*;

#if !macro
//@:genericBuild
class DeepStateContainer {
    public var asset(default, null) : AgeNameAsset;
    public final observable : ds.Observable<AgeNameAsset, AgeName>;

    public var state(get, never) : AgeName;
    function get_state() : AgeName return asset.state;

    public function new(asset : AgeNameAsset, middlewares : ImmutableArray<Middleware<AgeNameAsset,AgeName>> = null, observable : Observable<AgeNameAsset,AgeName> = null) {
        if(observable == null) observable = new Observable<AgeNameAsset, AgeName>();

        if(middlewares == null) middlewares = []; 
        middlewares = middlewares.concat([updateAsset, observable.observe]);

        this.observable = observable;
        this.asset = asset.copy(asset.state, middlewares);
    }

    function updateAsset(asset : AgeNameAsset, next : Action -> AgeNameAsset, action : Action) : AgeNameAsset {
        return this.asset = next(action);
    }
}

typedef AgeName = {
	final age : Int;
	final name : String;
}

class AgeNameAsset extends DeepState<AgeNameAsset, AgeName> {}
#end
