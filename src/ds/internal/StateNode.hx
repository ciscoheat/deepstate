package ds.internal;

import ds.ImmutableArray;

enum StateNode {
    Typedef(name : String, fields : ImmutableArray<StateNode>);
    Array(name : String);
    List(name : String);
    Object(name : String, typePath : haxe.macro.Expr.TypePath, fields : ImmutableArray<StateNode>);
    Var(name : String, defaultValue : Any);
}
