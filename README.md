# DeepState

## Introduction and a wake-up call

### TL;DR

DeepState is a simple and useful immutable state container library for Haxe 4. Keep reading in the [Getting started](#getting-started) part.

### Introduction

As trends come and go, extracting their essential parts is important if we want progress, which, unfortunately, usually turns out to be a repetition of history instead. So when the trend for libraries like Redux are waning, let's see if we can actually learn from it in a deeper way than just jumping to the next train.

What did we get with the flux/redux library movement? We got plenty of stuff, like *reducers, thunks, sagas, combined reducers, dispatchers, actions, action creators...* Concepts that would make an aspiring programmer feel like there is a mountain to climb before they all fuse together into glorious understanding. It's quite a climb, but at the top, what a moment! What pride! You just want to shout from the peak how useful are all those *reducers, thunks, sagas, combined reducers, dispatchers, actions and action creators.* And you will. You talk to people about it, you encourage them to start climbing too, you write tutorials, you make everything as simple as it can possibly be, even abstracting them away until it actually feels like *you're not using them!* And life goes on, until one day:

![Redux is](https://ciscoheat.github.io/deepstate/redux-is.png)

Trends are changing again, and it could be tempting to check out MobX, Cerebral, Cycle.js and its competition. Now we got *observables, proxys, drivers, reactions...* and another mountain to climb. But perhaps this time you have work to do and not so much time for climbing. You also have enough work keeping track of those previous concepts, some that are starting to fade... sagas... what was that again? Does it really matter? Not for the customer, at least.

Is it fruitful in the long run, to learn yet another abstract idea that makes your project more complicated, and when it works nobody touches it because it's just "plumbing code"? Unfortunately it's now a growing part of your codebase, and unless you hold every abstract piece of not-so-impressive-anymore information in your head (because everyone is already talking about the next big thing), the code gets more and more painful to look at.

If you could make your customer happy and write reliable software without thunks, reducers, reactions, dispatchers, etc, wouldn't you?

Introducing **DeepState**, a state library that wants to go back to basics instead of abstractions.

### What to keep and what not

Since the beginning we've had this thing called **program state**, and just as in real life the state can be bloated and packed with confusing rules that seems more important than life itself. But full anarchy isn't advantageous either, letting anyone do everything they want, for example writing everywhere in memory without restrictions. A middle ground is best, a few clever rules that makes life easier and at the same time prevents fools from ruining things, or others from making mistakes with large repercussions.

Something that seems very useful in combination with program state is **immutability**. It prevents accidental overwrites, and we also start viewing data as facts, and the state as a snapshot in time, similar to version control software like Git, another idea that has proved to be very useful (especially if you've used bisect).

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
        // Instantiate your Contained Immutable Asset with an initial 
        // state.
        var asset = new CIA({
            score: 0,
            player: {
                firstName: "Wall",
                lastName: "Enberg"
            },
            timestamps: [Date.now()],
            json: { name: "Meitner", place: "Ljungaverk", year: 1945 }
        });

        // Now you can create actions using the update method. It will 
        // return a new asset of the same type.

        // It can be passed a normal value for direct updates.
        // The default action type is "Class.method" for the caller, 
        // so this action will have the type "Main.main":
        var next = asset.update(asset.state.score, 0);

        // A lambda function can also be used for incremental updates.
        next = next.update(next.state.score, score -> score + 1);

        // Partial objects are also supported.
        // This update is different from the two above, so the default 
        // name "Main.main" will clash. Add a unique action type as the 
        // last argument to fix it.
        next = next.update(
            next.state.player, {firstName: "Avery"}, "UpdatePlayer"
        );

        // For multiple (atomic) updates in the same action, pass in a
        // map declaration.
        next = next.update([
            next.state.score => s -> s + 10,
            next.state.player.firstName => "John Foster",
            next.state.timestamps => next.state.timestamps.push(Date.now())
        ], "BigUpdate");
        
        // Access state as you expect:
        trace(next.state);
        trace(next.state.score); // 11
    }
}
```

Run the test with: `haxe -x Main -lib deepstate`

`update` is the whole API for updating the state. It is type-checked at compile time.

## Middleware

Lets make the famous Redux time machine then! Middleware is a function that takes three arguments:

1. **asset:** The asset `S`, before any middleware was/is applied
1. **next:** A `next` function that will pass an `Action` to the next middleware
1. **action:** The current `Action`, that can be passed to `next` if no changes should be applied.

Finally, the middleware should return a new asset `S`, which is the same as returning `next(action)`.

Here's a logger that will save all state changes, which is just a quick solution. An alternative is to save the actions instead and replaying them, but that's left as an exercise!

```haxe
import ds.Action;
import DeepState.DeepStateConstructor;

// Apologies for the long type constraint, use Dynamic instead of S
// if you don't need specific type access, then it's not needed.
class MiddlewareLog<S : DeepState<S,T> & DeepStateConstructor<S,T>, T> {
    public function new() {}

    public final logs = new Array<{state: T, type: String, timestamp: Date}>();

    public function log(asset: S, next : Action -> S, action : Action) : S {
        // Get the next state
        var newState = next(action);

        // Log it and return it unchanged
        logs.push({state: newState.state, type: action.type, timestamp: Date.now()});
        return newState;
    }
}
```

Which then can be used in the asset as such:

```haxe
var logger = new MiddlewareLog<CIA, State>();
var asset = new CIA(initialState, [logger.log]);
```

To restore a previous state, at the moment you need to expose some revert method in the asset:

```haxe
class CIA extends DeepState<CIA, GameState> {
    public function revert(previous : GameState)
        return update(this.state, previous);
}

// Now you can turn back time:
var next = asset.revert(logger.logs[0].state);
```

Hopefully some standardized solution for this can be figured out. Open an issue if you have any ideas!

## Async operations

No assumptions are made about the actions, which means that any future behavior can be supported. For example, to support Promises, let them gather the required data, and finally call `update`.

```haxe
public function changeName(firstName : String, lastName : String) {
    return new Promise((resolve, reject) -> {
        api.checkValidName(firstName, lastName).then(() -> {
            var next = asset.update(asset.state.player, { 
                firstName: firstName, 
                lastName: lastName
            });
            resolve(next);
        }, reject);
    });
}
```

## Observable

The above functionality will get you far, you could for example create a middleware for your favorite web framework, redrawing or updating its components when the state updates. By popular request, an observable middleware has been added, making it easy to subscribe to state updates.

Create an `ds.Observable<S, T>` object to subscribe to changes:

```haxe
var observable = new ds.Observable<CIA, State>();
var asset = new CIA(someInitialState, [observable.observe]);

var subscriber = observable.subscribe(    
    asset.state.player,
    p -> trace('Player changed name to ${p.firstName} ${p.lastName}')
);

// You can observe multiple changes, and receive them in a single callback
observable.subscribe(
    asset.state.player, asset.state.score, 
    (player, score) -> trace('Player or score updated.')
);

// Later, time to unsubscribe
if(!subscriber.closed)
    subscriber.unsubscribe();
```

If you want to observe the state immediately upon subscription, which can be useful to populate objects, you can pass a state `T` as a final argument to `subscribe`.

The observer will only be called upon changes *on the selected parts of the state tree*. So in the first example, it won't be called if the score changed. If you want to observe all updates, call `subscribe` with a function that takes two parameters, the previous and updated state:

```haxe
var subscriber = observable.subscribe((prev, current) -> {
    if(prev.score < current.score) trace("Score increased!");
});
```

## DataClass support

The library [DataClass](https://github.com/ciscoheat/dataclass) is a nice supplement to deepstate, since it has got validation, null checks, JSON export, etc, for your data. It works out-of-the-box, simply create a DataClass with only final fields, and use it as `T` in `DeepState<S, T>`.

## Roadmap

The project has just started, so assume API changes. The aim is to support at least the following:

- [x] Middleware
- [x] Observable state
- [x] Support for DataClass
- [x] Making the asset itself immutable, instead of treating it as a state container
- [ ] Default state initialization
- [ ] Support for objects with a Map-like interface
- [ ] Your choice! Create an issue to join in.

[![Build Status](https://travis-ci.org/ciscoheat/deepstate.svg?branch=master)](https://travis-ci.org/ciscoheat/deepstate)
