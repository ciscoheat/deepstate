import ds.Action;

// This is your program state, where all fields must be final.
typedef State = {
    final score : Int;
    // Nested structures are supported, as long as all fields are final.
    final player : {
        final firstName : String;
        final lastName : String;
    }
    // Prefix Array, List and Map with "ds.Immutable"
    final timestamps : ds.ImmutableArray<Date>;
    // For json structures:
    final json : ds.ImmutableJson;
}

// Create a Contained Immutable Asset class by extending DeepState<S, T>,
// where S is the asset type, and T is the type of your program state.
class CIA extends DeepState<CIA, State> {}

// And a Main class to use it.
class Main {
    static function main() {
        var logger = new MiddlewareLog<CIA, State>();
        var observable = new ds.Observable<CIA, State>();

        // Instantiate your Contained Immutable Asset with an initial state
        var asset = new CIA({
            score: 0,
            player: {
                firstName: "Wall",
                lastName: "Enberg"
            },
            timestamps: [Date.now()],
            json: { name: "Meitner", place: "Ljungaverk", year: 1945 }
        }, [logger.log, observable.observe]);

        //////////////////////////////////////////////////////////////////

        var unsubscriber = observable.subscribe(
            asset.state.player, 
            p -> trace('Player changed name to ${p.firstName} ${p.lastName}')
        );

        // You can observe multiple changes, and receive them in a single callback
        observable.subscribe(
            asset.state.player, asset.state.score, 
            (player, score) -> trace('Player or score updated.')
        );

        observable.subscribe((prev, current) -> {
            if(prev.score < current.score) trace("Score increased!");
        });

        //////////////////////////////////////////////////////////////////

        // Now create actions using the update method. It will return a
        // new asset of the same type.

        // It can be passed a normal value for direct updates
        var next = asset.update(asset.state.score, 0);

        // Or a lambda function
        next = next.update(next.state.score, score -> score + 1);

        // Or a partial object
        next = next.update(next.state.player, {firstName: "Avery"}, "UpdatePlayer");

        // It could also be passed a map declaration, 
        // for multiple updates in the same action
        next = next.update([
            next.state.score => s -> s + 10,
            next.state.player.firstName => "John Foster",
            next.state.timestamps => next.state.timestamps.push(Date.now())
        ], "BigUpdate");
        
        // Access state as you expect:
        trace(next.state);
        trace(next.state.score); // 11

        //////////////////////////////////////////////////////////////////

        // Later, time to unsubscribe
        if(!unsubscriber.closed)
            unsubscriber.unsubscribe();

        //////////////////////////////////////////////////////////////////
    }
}

class MiddlewareLog<S : DeepState<S,T>, T> {
    public function new() {}

    public final logs = new Array<{state: T, type: String, timestamp: Date}>();

    public function log(state: S, next : Action -> S, action : Action) : S {
        // Get the next state
        var newState = next(action);

        // Log it and return it unchanged
        logs.push({state: newState.state, type: action.type, timestamp: Date.now()});
        return newState;
    }
}
