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

    public var state(get, never) : T;
    function get_state() : T return this.asset.state;

    public function new(
        asset : DeepState<T>, 
        middlewares : ImmutableArray<Middleware<T>> = null, 
        observable : Observable<T> = null
    ) {        
        this.observable = if(observable == null) observable = new Observable<T>()
        else observable;

        this.asset = if(asset == null) null
        else {
            if(middlewares == null) middlewares = [];
            asset.copy(asset.state, middlewares.concat([updateAsset]));
        }
    }

    function updateAsset(asset, next, action) {
        return this.observable.observe(asset, (a) -> this.asset = next(a), action);
    }

    @:noCompletion public function subscribeObserver(observer: Observer<T>, immediateCall : Null<T> = null) : Subscription {
        return this.observable.subscribeObserver(observer, immediateCall);
    }

    @:noCompletion public function updateState(action : Action) : Void {
        this.asset._updateState(action);
    }

    #end

    public macro function enclose(container : Expr, statePath : Expr, observable : Expr = null) {
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

        return macro new DeepStateContainer.EnclosedDeepStateContainer<$enclosureType>(container, () -> $statePath, $a{paths}, $observable);
    }

    public macro function update(container : Expr, args : Array<Expr>) {
        return Ds._update(container, args);
    }

    public macro function subscribe(container : Expr, paths : Array<Expr>) {
        return Observable._subscribe(container, paths);
    }
}

#if !macro
class EnclosedDeepStateContainer<T> extends DeepStateContainer<T> {
    final encompassing : DeepStateContainer<Dynamic>;
    final stateAccessor : Void -> T;
    final statePath : ImmutableArray<Action.PathAccess>;

    public function new(
        encompassing : DeepStateContainer<Dynamic>, 
        stateAccessor : Void -> T, 
        statePath : ImmutableArray<Action.PathAccess>,
        observable : Observable<T> = null
    ) {
        super(null, null, observable);

        this.encompassing = encompassing;
        this.stateAccessor = stateAccessor;
        this.statePath = statePath;
    }

    override function get_state() : T return stateAccessor();

    override function updateAsset(asset, next, action) {
        return this.observable.observe(asset, next, action);
    }

    @:noCompletion override public function updateState(action : Action) : Void {
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