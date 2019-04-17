#if macro
import ds.internal.DeepStateUpdate as Ds;
import haxe.macro.Expr;
import haxe.macro.Context;
#end
import ds.*;
import ds.gen.DeepState;

using ds.MiddlewareAccess;

class DeepStateContainer<T> {
    #if !macro
    var asset : Null<DeepState<T>>;
    final observable : ds.Observable<T>;

    public var state(get, never) : T;
    function get_state() : T return this.asset.state;
    #end

    public function new(asset : DeepState<T>, observable : Observable<T> = null) {
        // The compilation server seems to require a constructor in macro mode
        #if !macro
        this.observable = observable == null ? new Observable<T>() : observable;

        if(asset == null) 
            this.asset = null;
        else {
            this.asset = asset.copy(null, asset.middleware().concat([updateMutableAsset]));
            this.update(this.state = asset.state);
        }
        #end
    }

    #if !macro
    function updateMutableAsset(asset, next, action) {
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
        // In display mode, return the actual arguments to use them in the returned expression, 
        // otherwise autocompletion doesn't work in the macro function call.
        if(Context.defined("display") || Context.defined("display-details")) {
            return macro $statePath;
        }

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
        super(null, observable);

        this.encompassing = encompassing;
        this.stateAccessor = stateAccessor;
        this.statePath = statePath;
    }

    override function get_state() : T return stateAccessor();

    override function updateMutableAsset(asset, next, action) {
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