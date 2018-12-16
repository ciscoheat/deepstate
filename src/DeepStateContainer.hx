import haxe.macro.ExprTools;
import DeepState as Ds;
import ds.*;
import ds.gen.DeepState;
import haxe.macro.Expr;
import haxe.macro.Context;

class DeepStateContainer<T> {
    #if !macro
    var asset : DeepState<T>;
    final observable : ds.Observable<T>;

    public var state(get, never) : T;
    function get_state() : T return asset.state;

    public function new(asset : DeepState<T>, middlewares : ImmutableArray<Middleware<T>> = null, observable : Observable<T> = null) {
        if(asset == null) throw "asset is null";
        if(observable == null) observable = new Observable<T>();

        if(middlewares == null) middlewares = []; 
        middlewares = middlewares.concat([updateAsset]);

        this.observable = observable;
        this.asset = asset.copy(asset.state, middlewares);
    }

    function updateAsset(asset, next, action) {
        this.observable.observe(asset, (a) -> this.asset = next(a), action);
        return this.asset;
    }

    @:noCompletion public function createEnclosure<S>(
        asset : DeepState<S>, 
        statePath : ImmutableArray<Action.PathAccess>, 
        middlewares : ImmutableArray<Middleware<S>> = null, 
        observable : Observable<S> = null
    ) : DeepStateContainer<S> {
        var newMiddlewares : ImmutableArray<Middleware<S>> = middlewares == null ? [] : middlewares;
        newMiddlewares = newMiddlewares.push((asset, next, action) -> {
            var nextAsset = next(action);
            this.updateState({
                type: action.type,
                updates: [{
                    path: statePath,
                    value: nextAsset.state
                }]
            });
            return nextAsset;
        });

        
        return new DeepStateContainer<S>(asset, newMiddlewares, observable);
    }

    @:noCompletion public function subscribeObserver(observer: Observer<T>, immediateCall : Null<T> = null) : Subscription {
        return this.observable.subscribeObserver(observer, immediateCall);
    }

    @:noCompletion public function updateState(action : Action) : Void {
        this.asset._updateState(action);
    }

    #end

    public macro function enclose(container : Expr, statePath : Expr, middlewares : Expr = null, observable : Expr = null) {
        var enclosureType = Context.toComplexType(try Context.typeof(statePath)
        catch(e : Dynamic) {
            Context.error("Cannot find type in state, please provide a type hint.", statePath.pos);
        });
        switch enclosureType {
            case TAnonymous(_):
                Context.error("Create a typedef of this anonymous type, to use it in DeepState.", statePath.pos);
            case _:
        }

        var paths = [for(p in Ds.pathAccessExpr(statePath)) switch p {
            case Field(name): macro ds.PathAccess.Field($v{name});
            case _: Context.error("Cannot create an enclosure on array or map access.", statePath.pos);
        }];

        return macro container.createEnclosure(new DeepState<$enclosureType>($statePath), $a{paths}, $middlewares, $observable);
    }

    public macro function update(container : Expr, args : Array<Expr>) {
        return Ds._update(container, args);
    }

    public macro function subscribe(container : Expr, paths : Array<Expr>) {
        return Observable._subscribe(container, paths);
    }
}
