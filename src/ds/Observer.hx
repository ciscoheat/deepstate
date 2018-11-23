package ds;

import haxe.Constraints;

/**
 * Receiving data from possible changes in an asset.
 */
enum Observer<T> {
    Partial(paths : ImmutableArray<String>, listener : Function);
    Full(listener : T -> T -> Void);
}
