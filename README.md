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

// Extend DeepState<T>, where T is your state structure.
class TestState extends DeepState<GameState> {
    public function new(initialState) super(initialState);

    // If you prefer, group actions/reducers in this class
    public function addScore(add : Int) {
        return this.updateIn(state.score, state.score + add);
    }
}

class Main {
    static function main() {
        // Create your Contained Immutable Asset, with an initial state
        var CIA = new TestState({
            score: 0,
            player: {
                firstName: "Wall",
                lastName: "Enberg"
            },
            timestamps: [Date.now()]
        });

        // Access state as you expect:
        var score = CIA.state.score;
        trace(score);

        // Update the state by the asset methods, or directly
        var newState = CIA.addScore(1);
        trace(newState.score);

        // Reset score
        CIA.updateIn(CIA.state.score, 0);
        trace(CIA.state.score);
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
