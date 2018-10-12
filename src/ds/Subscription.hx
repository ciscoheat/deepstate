package ds;

import haxe.Constraints;

/**
 * A subscriber to changes in an asset
 */
typedef Subscription = {
    /**
     * Paths to listen for changes
     */
    final paths : ImmutableArray<String>;

    /**
     * Function to call upon change in one of the paths.
     * Must have the same number of arguments as the length of paths.
     */
    final listener : Function;
}
