package ds;

//            function(state, next,           action)
typedef Middleware<S> = S -> (Action -> S) -> Action -> S;
