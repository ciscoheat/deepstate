import haxe.ds.Option;
import buddy.CompilationShould;
import ds.*;

import haxe.macro.Expr;

using buddy.Should;

typedef TestState = {
    final score : Int;
    final person : {
        final name : {
            final firstName : String;
            final lastName : String;
        }
    }
    final timestamps : ImmutableArray<Date>;
        final json : ImmutableJson;
}

///////////////////////////////////////////////////////////

class CIA extends DeepState<CIA, TestState> {
    public function new(initialState, middlewares = null, listeners = null) 
        super(initialState, middlewares, listeners);
}

class DeepStateImmutableAssetTests extends buddy.SingleSuite {
    public function new() {
        var asset : CIA;
        var initialState : TestState = {
            score: 0,
            person: {
                name: { firstName: "Wall", lastName: "Enberg" }
            },
            timestamps: [],
            json: { 
                event: "Kreuger liquidation", 
                place: "Paris", 
                years: {from: 1932, to: 1941},
                involved: ["Hugo Stenbeck", "Jacob Wallenberg", "Price Waterhouse"]
            }
        };
        beforeEach({
            asset = new CIA(initialState);
        });

        @include describe("The Deep State with -D deepstate-immutable-asset", {
            it("should return a new asset for each action", {
                var newAsset = asset.updateIn(asset.state.score, 20);

                newAsset.should.not.be(null);
                newAsset.should.not.be(asset);
                newAsset.state.should.not.be(asset.state);

                newAsset.state.score.should.be(20);
                asset.state.score.should.be(0);
            });
        });

        /////////////////////////////////////////////////////////////

        /*
        describe("Subscribers", {
            describe("The subscribeTo method", {
                it("should subscribe to a part of the state tree", {
                    var newName : String = null;
                    var nameCalls = 0, lastNameCalls = 0;

                    var unsub = asset.subscribeTo(asset.state.person.name, name -> {
                        newName = name.firstName + " " + name.lastName;
                        nameCalls++;
                    });

                    asset.subscribeTo(asset.state.person.name.lastName, lastName -> {
                        lastNameCalls++;
                    });

                    asset.changeFirstName("Avery");
                    newName.should.be("Avery Enberg");
                    nameCalls.should.be(1);
                    lastNameCalls.should.be(0);

                    asset.changeFirstName("Avery");
                    nameCalls.should.be(2);
                    lastNameCalls.should.be(0);

                    asset.updateIn(asset.state.person.name.lastName, "Dulles");
                    asset.state.person.name.lastName.should.be("Dulles");
                    newName.should.be("Avery Dulles");
                    nameCalls.should.be(3);
                    lastNameCalls.should.be(1);

                    unsub(); // Unsubscribing from name changes

                    asset.changeFirstName("John Foster");
                    asset.state.person.name.firstName.should.be("John Foster");
                    asset.state.person.name.lastName.should.be("Dulles");
                    newName.should.be("Avery Dulles");
                    nameCalls.should.be(3);
                    lastNameCalls.should.be(1);
                });

                it("should subscribe with multiple checks if passed multiple methods", {
                    var newName : String = null;
                    var multiCalls = 0;

                    asset.subscribeTo(
                        asset.state.person.name, asset.state.score,
                        (name, score) -> {
                            newName = name.firstName + " " + name.lastName + ' (${asset.state.score})';
                            multiCalls++;
                        }
                    );

                    asset.changeFirstName("Avery");
                    newName.should.be("Avery Enberg (0)");
                    multiCalls.should.be(1);

                    asset.updateIn(asset.state, nextState);

                    multiCalls.should.be(2);
                    asset.state.score.should.be(1);
                    newName.should.be("Montagu Norman (1)");
                });

                it("should not compile if listener has incorrect number of arguments", {
                    CompilationShould.failFor(asset.subscribeTo(
                        asset.state.person.name, asset.state.score, 
                        (name) -> null
                    ));
                });

                it("should be able to subscribe to the whole state tree", {
                    asset.subscribeTo(asset.state, (state) -> state.score.should.be(0), true);
                });

                it("should subscribe to the whole state if passing a function with two arguments", {
                    asset.subscribeTo((prev, current) -> {
                        prev.should.not.be(current);
                        prev.score.should.be(0);
                        current.score.should.be(1);
                    });

                    asset.addScore(1);

                    var calledImmediately = false;
                    asset.subscribeTo((prev, current) -> {
                        calledImmediately = true;
                    }, true);

                    calledImmediately.should.be(true);
                });

                it("should throw an exception when subscribing to a non-existing state field", {
                    function subscribeToNonexistingPath() {
                        asset.subscribe(Partial(["notExisting"], name -> null));
                        asset.changeFirstName("Anything");
                    }

                    subscribeToNonexistingPath.should.throwType(String);
                    CompilationShould.failFor(asset.subscribeTo(asset.state.notExisting, name -> null));
                });

                it("should be able to immediately trigger the listener", {
                    var nameCalls = 0;

                    var unsub = asset.subscribeTo(asset.state.person.name, name -> {
                        nameCalls++;
                    });

                    nameCalls.should.be(0);

                    asset.subscribeTo(asset.state.person.name, name -> {
                        nameCalls++;
                    }, true);

                    nameCalls.should.be(1);
                });
            });
        });
        */
    }
}
