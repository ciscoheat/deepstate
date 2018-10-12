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
}

class Person implements DataClass {
    public final firstName : String;
    public final lastName : String;
}

class DataClassState implements DataClass {
    public final id : Int;
    public final name : Person;
}

///////////////////////////////////////////////////////////

class CIA extends DeepState<TestState> {
    public function new(initialState, middlewares = null) 
        super(initialState, middlewares);

    public function addScore(add : Int) {
        return updateIn(state.score, state.score + add);
    }

    public function changeFirstName(firstName) {
        return updateIn(state.person.name.firstName, firstName);
    }
}

/*
class DataClassStore extends DeepState<DataClassState> {
    public function new(initialState) super(initialState);
}
*/

class MiddlewareLog {
    public function new() {}

    public static var logCount = new Array<String>();

    public var logs(default, null) = new Array<{state: TestState, type: String}>();

    public function log(state: TestState, next : Action -> TestState, action : Action) : TestState {
        var nextState = next(action);
        logs.push({state: nextState, type: action.type});
        logCount.push("MiddlewareLog");
        return nextState;
    }
}

class MiddlewareAlert {
    public function new() {}

    public var alerts(default, null) = 0;

    public function alertOn(actionType : String) {
        return function(state: Dynamic, next : Action -> Dynamic, action : Action) {
            if(action.type == actionType) {
                alerts++;
                MiddlewareLog.logCount.push("MiddlewareAlert");
            }
            return next(action);
        }
    }
}

///////////////////////////////////////////////////////////

class DeepStateTests extends buddy.SingleSuite {
    public function new() {
        var asset : CIA;
        var initialState : TestState = {
            score: 0,
            person: {
                name: { firstName: "Wall", lastName: "Enberg"}
            },
            timestamps: []
        };
        var nextState : TestState = {
            score: 1, 
            person: {
                name: {
                    firstName: "Montagu", lastName: "Norman"
                }
            },
            timestamps: [Date.now()]
        };

        beforeEach({
            asset = new CIA(initialState);
        });

        describe("The Deep State", {
            function testIdentity(newState : TestState) {
                newState.should.be(asset.state);
                newState.should.not.be(null);
                newState.should.not.be(initialState);
            }

            it("should update the whole state if specified", {
                CompilationShould.failFor(
                    asset.state = nextState
                );

                var newState = asset.update({
                    type: "full_update", 
                    updates: [{path: "", value: nextState}]
                });

                newState.should.not.be(null);
                newState.should.be(asset.state);
                newState.timestamps[0].getTime().should.beGreaterThan(0);

                newState.score.should.be(1);
                newState.person.name.firstName.should.be("Montagu");
                newState.person.name.lastName.should.be("Norman");
            });

            it("should not modify the first state object when multiple changes are made", {
                var newState = asset.update({type: 'test', updates: [
                    { 
                        path: "", 
                        value: nextState
                    },
                    { 
                        path: "person.name", 
                        value: { firstName: "Avery", lastName: "Dulles" }
                    }
                ]});

                testIdentity(newState);
                newState.score.should.be(1);
                newState.person.should.not.be(initialState.person);
                newState.person.name.firstName.should.be("Avery");
                newState.person.name.lastName.should.be("Dulles");

                nextState.should.not.be(newState);
                nextState.person.name.firstName.should.be("Montagu");
                nextState.person.name.lastName.should.be("Norman");
            });

            it("should update fields in the middle of the state tree", {
                var newState = asset.update({type: 'test', updates: [{ 
                    path: "person.name", 
                    value: { firstName: "Montagu", lastName: "Norman" }
                }]});

                testIdentity(newState);
                newState.score.should.be(0);
                newState.person.should.not.be(initialState.person);
                newState.person.name.firstName.should.be("Montagu");
                newState.person.name.lastName.should.be("Norman");
            });

            it("should update fields at the end of the state tree", {
                var newState = asset.update({type: 'test', updates: [{ 
                    path: "person.name.firstName", 
                    value: "Wallan"
                }]});

                testIdentity(newState);
                newState.score.should.be(0);
                newState.person.should.not.be(initialState.person);
                newState.person.name.firstName.should.be("Wallan");
                newState.person.name.lastName.should.be("Enberg");
                
                CompilationShould.failFor(
                    newState.person.name.firstName = "Ture"
                );

                CompilationShould.failFor(
                    asset.state.person.name.firstName = "Ture"
                );
            });

            it("should update fields at the top of the state tree", {
                var newState = asset.update({type: 'test', updates: [{ 
                    path: "score", 
                    value: 10
                }]});

                testIdentity(newState);
                newState.score.should.be(10);
                newState.person.name.firstName.should.be("Wall");
                newState.person.name.lastName.should.be("Enberg");

                var newState2 = asset.addScore(20);
                newState2.should.not.be(newState);
                newState2.score.should.be(30);
            });

            it("should update several fields if specified in the Action", {
                var timestamps = asset.state.timestamps;
                var newState = asset.update({type: 'test_multiple', updates: [
                    { path: "score", value: 100 },
                    { path: "person.name.lastName", value: "Norman" },
                    { path: "timestamps", value: timestamps.push(Date.now()) }
                ]});

                testIdentity(newState);
                newState.score.should.be(100);

                newState.person.name.firstName.should.be("Wall");
                newState.person.name.lastName.should.be("Norman");

                newState.timestamps.length.should.be(1);
                newState.timestamps.should.not.be(timestamps);
            });

            it("should throw if a field key doesn't exist in the state tree", {
                asset.update.bind({type: "test", updates: [{path: "some", value: "test"}]})
                    .should.throwType(String);

                asset.update.bind({type: "test", updates: [{path: "some.missing.field", value: 10}]})
                    .should.throwType(String);
            });

            /////////////////////////////////////////////////////////

            describe("The updateIn method", {
                it("should use a lambda function to update a field if passed a function", {
                    asset.updateIn(asset.state.score, score -> 1);
                    asset.updateIn(asset.state.score, score -> score + 2);
                    asset.state.score.should.be(3);
                });

                it("should update fields when given a partial object", {
                    var newState = asset.updateIn(asset.state.person.name, {firstName: "Marcus"});

                    testIdentity(newState);
                    newState.person.name.firstName.should.be("Marcus");
                    newState.person.name.lastName.should.be("Enberg");

                    CompilationShould.failFor(
                        asset.updateIn(asset.state.person.name, {firstName: 123})
                    );

                    CompilationShould.failFor(
                        asset.updateIn(asset.state.person.name, {doesntExist: 123})
                    );
                });

                it("should update the whole field when given a complete object", {
                    var newState = asset.updateIn(asset.state.person.name, {
                        firstName: "Marcus", lastName: "Wallenberg"
                    });

                    testIdentity(newState);
                    newState.person.name.firstName.should.be("Marcus");
                    newState.person.name.lastName.should.be("Wallenberg");
                });

                it("should be able to update a field if passed a single value", {
                    var storeVar : CIA = asset;
                    var newState = storeVar.changeFirstName("Montagu");
                    //var newState = storeVar.updateIn(storeVar.state.person.name.firstName, "Montagu");

                    CompilationShould.failFor(storeVar.updateIn(storeVar.state.notAField, "Montagu"));

                    testIdentity(newState);
                    newState.score.should.be(0);
                    newState.person.name.firstName.should.be("Montagu");
                    newState.person.name.lastName.should.be("Enberg");
                });

                it("should update the whole state if specified", {
                    var newState = asset.updateIn(asset.state, nextState);

                    newState.should.not.be(null);
                    newState.should.be(asset.state);
                    newState.timestamps[0].getTime().should.beGreaterThan(0);

                    newState.score.should.be(1);
                    newState.person.name.firstName.should.be("Montagu");
                    newState.person.name.lastName.should.be("Norman");
                });

                it("should update several values in one action if given a map", {
                    var newState = asset.updateMap([
                        asset.state.score => score -> score + 3,
                        asset.state.person.name.lastName => "Dulles",
                        asset.state.person.name => {firstName: "John Foster"}
                    ]);

                    testIdentity(newState);
                    newState.score.should.be(3);
                    newState.person.name.firstName.should.be("John Foster");
                    newState.person.name.lastName.should.be("Dulles");

                    CompilationShould.failFor(asset.updateMap([1,2,3]));
                    CompilationShould.failFor(asset.updateMap([a => "b"]));
                    CompilationShould.failFor(asset.updateMap([asset.state.score => "not an int"]));
                });

                it("should unify between arguments for type safety", {
                    CompilationShould.failFor(asset.changeFirstName(123));
                });
            });
        });

        /////////////////////////////////////////////////////////////

        describe("Middleware", {
            var logger : MiddlewareLog;
            var alert : MiddlewareAlert;

            beforeEach({
                logger = new MiddlewareLog();
                alert = new MiddlewareAlert();
                asset = new CIA(initialState, [
                    logger.log, 
                    alert.alertOn("CIA.addScore")
                ]);
                MiddlewareLog.logCount = [];
            });

            it("should be applied in the correct order", {
                asset.addScore(10);

                logger.logs.length.should.be(1);
                logger.logs[0].type.should.be("CIA.addScore");
                logger.logs[0].state.score.should.be(10);

                alert.alerts.should.be(1);

                MiddlewareLog.logCount.should.containExactly(["MiddlewareAlert", "MiddlewareLog"]);

                asset.state.score.should.be(10);
            });
        });

        /////////////////////////////////////////////////////////////

        describe("Observers", {
            it("should subscribe with the subscribe method", {
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

            it("should subscribe with multiple checks if passed an array", {
                var newName : String = null;
                var multiCalls = 0;

                asset.subscribeTo(
                    [asset.state.person.name, asset.state.score], 
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
                    [asset.state.person.name, asset.state.score], 
                    (name) -> null
                ));
            });

            it("should throw an exception when subscribing to a non-existing state field", {
                function subscribeToNonexistingPath() {
                    asset.subscribe({paths: ["notExisting"], listener: name -> null});
                    asset.changeFirstName("Anything");
                }

                subscribeToNonexistingPath.should.throwType(String);
                CompilationShould.failFor(asset.subscribeTo(asset.state.notExisting, name -> null));
            });
        });

        /////////////////////////////////////////////////////////////

        describe("Immutable datastructures", {
            describe("ImmutableMap", {
                it("should work with array access", {
                    var map = ["A" => 1];
                    var immutableMap : ImmutableMap<String, Int> = map;
                    //var newMap = immutableMap.set("B", 2);

                    [for(v in immutableMap.keys()) v].length.should.be(1);
                    immutableMap["A"].should.be(1);
                    //[for(v in newMap.keys()) v].length.should.be(2);
                    //immutableMap.should.not.be(newMap);
                });
            });

            describe("ImmutableArray", {
                it("should work with array access", {
                    var immutableArray = new ImmutableArray<String>(["A"]);
                    immutableArray.length.should.be(1);
                    immutableArray[0].should.be("A");
                });

                it("should return a new array for the modification methods", {
                    var immutableArray = new ImmutableArray<String>(["A"]);
                    var array2 = immutableArray.push("B");

                    array2.should.not.be(immutableArray);
                    array2.length.should.be(2);
                    array2[0].should.be("A");
                    array2[1].should.be("B");
                });

                it("should return the same array if nothing could be removed from it", {
                    var immutableArray = new ImmutableArray<String>(["A"]);
                    immutableArray.remove("B").should.be(immutableArray);
                    immutableArray.remove("A").should.not.be(immutableArray);
                });

                it("should be able to access first and last elements with methods", {
                    var array = ["A", "B"];
                    var immutableArray = new ImmutableArray<String>(array);

                    immutableArray.first().should.equal(Option.Some("A"));
                    immutableArray.last().should.equal(Option.Some("B"));

                    var empty = new ImmutableArray<String>([]);
                    empty.first().should.equal(None);
                    empty.last().should.equal(None);
                });
            });

            describe("ImmutableList", {
                it("should convert an array to list", {
                    var list : ImmutableList<String> = ["A"];
                    list.length.should.be(1);
                    list.first().should.be("A");
                });

                it("should return the same list if nothing was removed", {
                    var list : ImmutableList<String> = ["A", "B"];
                    list.remove("C").should.be(list);
                    list.remove("A").should.not.be(list);
                });
            });
        });
    }
}
