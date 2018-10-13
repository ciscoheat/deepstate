package ds;

import haxe.Constraints;

/**
 * A subscriber to changes in an asset
 */
enum Subscription<T> {
    Partial(paths : ImmutableArray<String>, listener : Function);
    Full(listener : T -> T -> Void);
}
