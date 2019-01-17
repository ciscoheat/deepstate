package ds;

class MiddlewareAccess {
    public static function middleware<T>(asset : ds.gen.DeepState<T>) : ds.ImmutableArray<Middleware<T>> {
        return asset.middlewares;
    }

    public static function copy<S : ds.gen.DeepState<T>, T>(
        asset : ds.gen.DeepState<T>, 
        newState : T = null, 
        middlewares : ImmutableArray<Middleware<T>> = null
    ) : S {
        return cast asset.copyAsset(newState, middlewares);
    }

    public static function allStateTypes<T>(asset : ds.gen.DeepState<T>) : Map<String, StateObjectType>
        return asset.stateTypes;

    public static function currentStateType<T>(asset : ds.gen.DeepState<T>) : StateObjectType
        return asset.stateType;
}
