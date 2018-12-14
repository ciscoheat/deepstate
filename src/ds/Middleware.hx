package ds;

typedef Middleware<T>
//  function(asset,                  next,                             action)
           = ds.gen.DeepState<T> -> (Action -> ds.gen.DeepState<T>) -> Action -> ds.gen.DeepState<T>;
