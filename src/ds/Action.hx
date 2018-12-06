package ds;

/**
 * The information package that will update an asset.
 */
typedef Action = {
    /**
     * What type of action is being performed
     */
    final type : String;

    /**
     * An array of paths into the state object, with
     * a value being changed.
     */
    final updates : ImmutableArray<{
        final path : ImmutableArray<PathAccess>;
        final value : Any;
    }>;
}

enum PathAccess {
    Field(name : String);
    Array(index : Int);
    Map(key : String);
}