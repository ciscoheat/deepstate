# DeepState

## Introduction and a wake-up call

### TL;DR

DeepState is a simple and useful immutable state container library for Haxe 4. Keep reading in the [Getting started](#getting-started) part.

### Introduction

As trends come and go, extracting their essential parts is important if we want progress, which, unfortunately, usually turns out to be a repetition of history instead. So when the trend for libraries like Redux are waning, let's see if we can actually learn from it in a deeper way than just jumping to the next train.

What did we get with the flux/redux library movement? We got plenty of stuff, like *reducers, thunks, sagas, combined reducers, dispatchers, actions, action creators...* Concepts that would make an aspiring programmer feel like there is a mountain to climb before they all fuse together into glorious understanding. It's quite a climb, but at the top, what a moment! What pride! You just want to shout from the peak how useful are all those *reducers, thunks, sagas, combined reducers, dispatchers, actions and action creators.* And you will. You talk to people about it, you encourage them to start climbing too, you write tutorials, you make everything as simple as it can possibly be, even abstracting them away until it actually feels like *you're not using them!* And life goes on, until one day:

![Redux is](https://pli.io/2jPhAy.png)

Trends are changing again, and it could be tempting to check out MobX, Cerebral, Cycle.js and its competition. Now we got *observables, proxys, drivers, reactions...* and another mountain to climb. But perhaps this time you have work to do and not so much time for climbing. You also have enough work keeping track of those previous concepts, some that are starting to fade... sagas... what was that again? Does it really matter? Not for the customer, at least.

Is it fruitful in the long run, to learn yet another abstract idea that makes your project more complicated, and when it works nobody touches it because it's just "plumbing code"? Unfortunately it's now a growing part of your codebase, and unless you hold every abstract piece of not-so-impressive-anymore information in your head (because everyone is already talking about the next big thing), the code gets more and more painful to look at.

If you could make your customer happy and write reliable software without thunks, reducers, reactions, dispatchers, etc, wouldn't you?

Introducing **DeepState**, a state library that wants to go back to basics instead of abstractions.

### What to keep and what not

Since the beginning we've had this thing called **program state**, and just as in real life the state can be bloated and packed with confusing rules that seems more important than life itself. But full anarchy isn't advantageous either, letting anyone do everything they want, for example writing everywhere in memory without restrictions. A middle ground is best, a few clever rules that makes life easier and at the same time prevents fools from ruining things, or others from making mistakes with large repercussions.

Something that seems very useful in combination with program state is **immutability**. Apart from preventing accidental overwrites, we start viewing data as facts, and the state as a snapshot in time, similar to version control software like Git, another idea that has proved to be very useful (especially if you've used bisect).

Making the state become a version controlled repository and commit data to it is appealing, but the whole idea of committing is perhaps not fully compatible with a process like running software. In Git you stage changes, review them and finally commit them with a descriptive message. There are also no rules to what can be deleted and added in the repository. When programming we express known change sets, and they will be applied by a machine at runtime. Therefore the concept of **actions**, taken from Flux and Redux, makes sense as a simplified commit. They are similar to events but applies only to state updates.

Finally, **middleware** has proved to be useful as a simpler version of Aspect-oriented programming. The idea is to be able to inspect and apply changes to the actions, logging and authorization being the standard examples. This enables us to save the program state to some kind of repository if you will, making that time machine possible, because the state isn't saved anywhere as default. Why not? The problem is similar to what happens in async programming, where the trends have produced a plethora of options. Should you use callbacks? Promises? A specific promise library? Async/await?

The answer is that it depends on your project, so here we need flexibility, instead of opinionated libraries.

Can we manage with only those three concepts? **Immutable program state, actions and middleware**? Let's find out.

## Getting started

You need Haxe 4 because of its support for immutable (final) data, so first go to [the download page](https://haxe.org/download/) and install the latest preview version or a nightly build.

Then install the lib:

`haxelib git deepstate https://github.com/ciscoheat/deepstate.git`

And create a test file called **Main.hx**:

```haxe
// This is your program state, where all fields must be final.
typedef GameState = {
    final score : Int;
    // Nested structures are supported, as long as all fields are final.
    final player : {
        final firstName : String;
        final lastName : String;
    }
    // For Arrays and Lists, use ImmutableArray and ImmutableList
    final timestamps : ds.ImmutableArray<Date>;
    // For json structures:
    final json : ds.ImmutableJson;
}

// Create a Contained Immutable Asset class by extending DeepState<T>,
// where T is the type of your program state.
class CIA extends DeepState<GameState> {
    // A default constructor is useful:
    public function new(initialState, middlewares = null) 
        super(initialState, middlewares);

    // Now create actions in this class, like this:

    public function resetScore() {
        // The updateIn method can be passed a normal value for direct updates
        return updateIn(state.score, 0);
    }

    public function addScore(add : Int) {
        // Or a lambda function
        return updateIn(state.score, score -> score + add);
    }

    public function setFirstName(name) {
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
```

That's the whole API for updating the state. Everything is type-checked at compile time, including that all fields are final.

Every method calling an `update` method is considered an action, we might as well call it an **action method**. The action type is automatically derived from the name of that method. You can supply your own type (a `String`) as a final parameter to the `update` methods if you want.

To complete the test, add a `Main` class to the **Main.hx** file:

```haxe
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
        trace(score); // 0

        // Update the state by the methods in the asset
        var newState = asset.addScore(10);

        trace(newState.score); // 10
        // Same as:
        trace(asset.state.score); // 10
    }
}
```

Execute it:

`haxe -x Main -lib deepstate`

## Middleware

Lets make this time machine then! Middleware is a function that takes three arguments:

1. **state:** The state `T` before any middleware was/is applied
1. **next:** A `next` function that will pass an `Action` to the next middleware
1. **action:** The current `Action`, that can be passed to `next` if no changes should be applied.

Finally, the middleware should return a new state `T`, which is the same as returning `next(action)`.

Here's a state logger that will save all state changes, which is just a quick solution. An alternative is to save the actions instead and replaying them, but that's left as an exercise!

```haxe
class MiddlewareLog<T> {
    public function new() {}

    public final logs(default, null) = new Array<{state: T, type: String, timestamp: Date}>();

    public function log(state: T, next : Action -> T, action : Action) : T {
        // Get the next state
        var newState = next(action);

        // Log it and return it unchanged
        logs.push({state: newState, type: action.type, timestamp: Date.now()});
        return newState;
    }
}
```

Which then can be used in the asset as such:

```haxe
var logger = new MiddlewareLog<CIA>();
var asset = new CIA(initialState, [logger.log]);
```

To restore a previous state, at the moment you need to expose some revert method in the asset:

```haxe
class CIA extends DeepState<GameState> {
    // ...
    public function revert(previous : GameState)
        updateIn(state, previous);
}

// Now you can turn back time:
asset.revert(logger.logs[0].state);
```

Hopefully some standardized solution for this can be figured out. Open an issue if you have any ideas!

## Async operations

As you may have noticed, no assumptions are made about the action methods, which means that any future behavior can be supported. To support Promises, just return them from your action methods.

```haxe
class CIAsync extends DeepState<GameState> {
    final api : YourApi;

    // Extend the default constructor:
    public function new(initialState, api : YourApi, middlewares = null) {
        super(initialState, middlewares);
        this.api = api;
    }

    // Return whatever you want, for example using Promises:
    public function changeName(firstName : String, lastName : String) {
        return new Promise((resolve, reject) -> {
            api.checkValidName(firstName, lastName).then(() -> {
                resolve(updateIn(state.player, { 
                    firstName: firstName, 
                    lastName: lastName
                }));
            }, reject);
        });
    }
}
```

## Subscriptions

The above functionality will get you far, you could for example create a middleware for your favorite web framework, redrawing or updating its components when the state updates. By popular request however, a listener/observer feature has been added, making it easy to subscribe to specific state changes.

Use `asset.subscribeTo` to listen to changes:

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

## DataClass support

The library [DataClass](https://github.com/ciscoheat/dataclass) is a nice supplement to deepstate, since it has got validation, null checks, JSON export, etc, for your data. It works out-of-the-box, simply create a DataClass with final fields, and use it in `DeepState<T>`.

## Compiler defines

`-D deepstate-public-update` - As default, the `update` methods can only be called from within the class that inherits from `DeepState<T>`, to keep state changes in the same place. With this define, they will become public, creating a kind of free-for-all state update object, instead of the more controlled situation with action methods.

## Roadmap

The project has just started, so assume API changes. The aim is to support at least the following:

- [x] Middleware
- [x] Observable state
- [x] Support for DataClass
- [ ] Support for objects with a Map-like interface
- [ ] An option for making the asset immutable as well, instead of treating it as a state container
- [ ] Your choice! Create an issue to join in.

[![Build Status](https://travis-ci.org/ciscoheat/deepstate.svg?branch=master)](https://travis-ci.org/ciscoheat/deepstate)
