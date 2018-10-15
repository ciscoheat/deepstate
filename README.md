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
    // For Arrays and Lists, use ImmutableArray and ImmutableList
    final timestamps : ds.ImmutableArray<Date>;
    // For json structures:
    final json : ds.ImmutableJson;
}

// Create a Contained Immutable Asset by extending DeepState<T>,
// where T is your state structure.
class CIA extends DeepState<GameState> {
    public function new(initialState, middlewares = null) 
        super(initialState, middlewares);

    // Group actions in this class:

    public function resetScore() {
        // The updateIn method can be passed a normal value for direct updates
        return this.updateIn(state.score, 0);
    }

    public function addScore(add : Int) {
        // Or a lambda function
        return updateIn(state.score, score -> score + add);
    }

    public function setFirstName(name = "Avery") {
        // Or a partial object
        return updateIn(state.player, {firstName: name});
    }

    public function multipleUpdates() {
        // The updateMap method should be passed a map declaration, 
        // for multiple updates in the same action
        return updateMap([
            state.score => s -> s + 10,
            state.player.firstName => "John Foster",
            state.timestamps => state.timestamps.push(Date.now())
        ]);
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
            timestamps: [Date.now()],
            json: { name: "Meitner", place: "Ljungaverk", year: 1945 }
        });
        
        // Access state as you expect:
        trace(asset.state);

        var score = asset.state.score;
        trace(score);

        // Update the state by the methods in the asset
        var newState = asset.addScore(1);

        trace(newState.score);
        // Same as:
        trace(asset.state.score);
    }
}
```

3) Make a quick test:

`haxe -x Main -lib deepstate`

## Middleware

A simple generic logging example:

```haxe
class MiddlewareLog {
    public function new() {}

    public var logs(default, null) = new Array<{state: Dynamic, type: String}>();

    public function log(state: Dynamic, next : Action -> Dynamic, action : Action) : Dynamic {
        var newState = next(action);
        logs.push({state: newState, type: action.type});
        return newState;
    }
}
```

Which can be used in the asset as such:

```haxe
var logger = new MiddlewareLog();
var asset = new CIA(initialState, [logger.log]);
```

## Change listeners / Observers

You can use `asset.subscribeTo` to listen to changes: 

```haxe
var unsubscribe = asset.subscribeTo(
    asset.state.player, 
    p -> trace('Player changed name to ${p.firstName} ${p.lastName}')
);

// Use an array to listen to multiple changes
asset.subscribeTo(
    asset.state.player, asset.state.score, 
    (player, score) -> trace('Player or score updated.')
);

// Later, time to unsubscribe
unsubscribe();
```

Note that the listener function will only be called upon changes *on the selected parts of the state tree*. So in the first example, it won't be called if the score changed. If you want to listen to every change, use `subscribeToState` instead, which will be called on every update:

```haxe
var unsubscribe = asset.subscribeToState((prev, current) -> {
    if(prev.score < current.score) trace("Score increased!");
});
```

## Compiler defines

`-D deepstate-public-update` - As default, the `update` methods can only be called from within the asset that inherits from `DeepState<T>`, to keep state changes in the same place. With this define, they will become public.

## Roadmap

The project has just started, so assume API changes. The aim is to support at least the following:

- [x] Middleware
- [x] Observable state
- [ ] Not just anonymous structures, but DataClass and objects with a Map-like interface
- [ ] Your choice! Create an issue to join in.

[![Build Status](https://travis-ci.org/ciscoheat/deepstate.svg?branch=master)](https://travis-ci.org/ciscoheat/deepstate)
