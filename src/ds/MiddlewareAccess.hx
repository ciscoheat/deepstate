package ds;

class MiddlewareAccess {
    public static function middleware<T>(asset : ds.gen.DeepState<T>) : ds.ImmutableArray<Middleware<T>> {
        return asset.middlewares;
    }
}
