# DeepState

An immutable state container for Haxe 4, similar to Redux.

## Quickstart

1) Install the lib:

`haxelib git deepstate https://github.com/ciscoheat/deepstate.git`

2) Create a test file called **Main.hx**:

```haxe
// This is your state structure, where all fields must be final.
typedef GameState = {
    final score : Int;
    // Nested structures must also be an anonymous structure.
    final player : {
        final firstName : String;
        final lastName : String;
    }
    // For Arrays, use ds.ImmutableArray
    final timestamps : ds.ImmutableArray<Date>;
}

// Create a Contained Immutable Asset (CIA) by extending DeepState<T>,
// where T is your state structure.
class CIA extends DeepState<GameState> {
    public function new(initialState) super(initialState);

    // If you prefer, group actions/reducers in this class
    public function addScore(add : Int) {
        var score = state.score;
        return this.updateIn(score, score + add);
    }
}

class Main {
    static function main() {
        // Instantiate your Contained Immutable Asset with an initial state
        var asset = new CIA({
            score: 0,
            player: {
                firstName: "Wall",
                lastName: "Enberg"
            },
            timestamps: [Date.now()]
        });

        // Access state as you expect:
        var score = asset.state.score;
        trace(score);

        // Update the state by the asset methods, or directly
        var newState = asset.addScore(1);
        trace(newState.score);

        // The updateIn method can be passed a normal value for direct updates
        asset.updateIn(asset.state.score, 0);
        trace(asset.state.score);

        // Or a lambda function
        asset.updateIn(asset.state.score, score -> score + 1);
        trace(asset.state.score);

        // Or a partial object
        asset.updateIn(asset.state.player, {firstName: "Allen"});
        trace(asset.state.player);

        // The updateMap method should be passed a map declaration, 
        // for multiple updates in the same action
        asset.updateMap([
            asset.state.score => s -> s + 10,
            asset.state.player.firstName => "John Foster"
        ]);
        trace(asset.state);
    }
}
```

3) Make a quick test:

`haxe -x Main -lib deepstate`

## Roadmap

The project has just started, so assume API changes. The aim is to support at least the following:

- [ ] Middleware/plugins
- [ ] Not just anonymous structures, but DataClass and objects with a Map-like interface
- [ ] Your choice! Create an issue to join in.

[![Build Status](https://travis-ci.org/ciscoheat/deepstate.svg?branch=master)](https://travis-ci.org/ciscoheat/deepstate)
