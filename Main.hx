// This is your program state, where all fields must be final.
typedef GameState = {
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

// Create a Contained Immutable Asset class by extending DeepState<T>,
// where T is the type of your program state.
class CIA extends DeepState<GameState> {
    public function new(initialState, middlewares = null) 
        super(initialState, middlewares);
}

// And a Main class to use it.
class Main {
    static function main() {
        // Instantiate your Contained Immutable Asset with an initial state
        var asset = new CIA({
            score: 0,
            player: {
                firstName: "Wall",
                lastName: "Enberg"
            },
            timestamps: [Date.now()],
            json: { name: "Meitner", place: "Ljungaverk", year: 1945 }
        });

        // Now create actions like this:

        // The updateIn method can be passed a normal value for direct updates
        asset.updateIn(asset.state.score, 0);

        // Or a lambda function
        asset.updateIn(asset.state.score, score -> score + 1);

        // Or a partial object
        asset.updateIn(asset.state.player, {firstName: "Avery"});

        // The updateMap method should be passed a map declaration, 
        // for multiple updates in the same action
        asset.updateMap([
            asset.state.score => s -> s + 10,
            asset.state.player.firstName => "John Foster",
            asset.state.timestamps => asset.state.timestamps.push(Date.now())
        ]);
        
        // Access state as you expect:
        trace(asset.state);
        trace(asset.state.score); // 11
    }
}