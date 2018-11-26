package ds;
import DeepState.DeepStateConstructor;

typedef Middleware<S : DeepState<S,T> & DeepStateConstructor<S,T>, T> 
// function(asset, next,           action)
           = S -> (Action -> S) -> Action -> S;
