package ds;
import DeepState.DeepStateConstructor;

typedef Middleware<T> 
// function(asset, next,           action)
           = DeepState<T> -> (Action -> DeepState<T>) -> Action -> DeepState<T>;
