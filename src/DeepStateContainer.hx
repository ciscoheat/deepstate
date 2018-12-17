import haxe.macro.ExprTools;
import DeepState as Ds;
import ds.*;
import ds.gen.DeepState;
import haxe.macro.Expr;
import haxe.macro.Context;

class DeepStateContainer<T> {
    #if !macro
    var asset : Null<DeepState<T>>;
    final observable : ds.Observable<T>;

    final encompassing : Null<DeepStateContainer<Dynamic>>;
    final stateAccessor : Void -> T;
    final statePath : ImmutableArray<Action.PathAccess>;

    public var state(get, never) : T;
    function get_state() : T return stateAccessor();

    public function new(
        asset : Null<DeepState<T>>, 
        middlewares : ImmutableArray<Middleware<T>> = null, 
        observable : Observable<T> = null, 

        encompassing : DeepStateContainer<Dynamic> = null,
        stateAccessor : Void -> T = null,
        statePath : ImmutableArray<Action.PathAccess> = null
    ) {
        if(observable == null) observable = new Observable<T>();
        this.observable = observable;

        if(encompassing == null) {
            if(asset == null) throw "asset is null";
            if(middlewares == null) middlewares = [];

            this.asset = asset.copy(asset.state, middlewares.concat([updateAsset]));
            this.encompassing = null;
            this.stateAccessor = () -> this.asset.state;
            this.statePath = null;            
        } else {
            if(asset != null) throw "asset must be null when creating an enclosure.";
            this.asset = null;
            this.encompassing = encompassing;
            this.stateAccessor = stateAccessor;
            this.statePath = statePath;
        }
    }

    function updateAsset(asset, next, action) {
        return this.observable.observe(asset, (a) -> this.asset = next(a), action);
    }

    @:noCompletion public function createEnclosure<S>(
        encompassing : DeepStateContainer<Dynamic>,
        stateAccessor : Void -> S,
        statePath : ImmutableArray<Action.PathAccess>, 
        //middlewares : ImmutableArray<Middleware<S>> = null, 
        observable : Observable<S> = null
    ) : DeepStateContainer<S> {
        return new DeepStateContainer<S>(null, null, observable, encompassing, stateAccessor, statePath);
    }

    @:noCompletion public function subscribeObserver(observer: Observer<T>, immediateCall : Null<T> = null) : Subscription {
        return this.observable.subscribeObserver(observer, immediateCall);
    }

    @:noCompletion public function updateState(action : Action) : Void {
        if(asset != null) this.asset._updateState(action)
        else {
            this.encompassing.updateState({
                type: action.type,
                updates: [for(u in action.updates) {
                    path: this.statePath.concat(u.path),
                    value: u.value
                }]
            });
        }
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

        return macro container.createEnclosure(container, () -> $statePath, $a{paths}, $observable);
    }

    public macro function update(container : Expr, args : Array<Expr>) {
        return Ds._update(container, args);
    }

    public macro function subscribe(container : Expr, paths : Array<Expr>) {
        return Observable._subscribe(container, paths);
    }
}
