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

typedef RecursiveState = {
    final node : RecursiveState;
    final value : String;
}

class Person implements DataClass {
    public final firstName : String;
    public final lastName : String;
    public final created : Date;

    public function name() return '$firstName $lastName';
}

class DataClassState implements DataClass {
    @validate(_ >= 0)
    public final score : Int = 100;
    public final person : Person;
}

///////////////////////////////////////////////////////////

class CIA extends DeepState<TestState> {
    public function new(initialState, middlewares = null) 
        super(initialState, middlewares);

    public function addScore(add : Int) {
        return update(state.score, state.score + add);
    }

    public function changeFirstName(firstName) {
        return update(state.person.name.firstName, firstName);
    }
}

class FBI extends DeepState<DataClassState> {
    public function new(initialState, middlewares = null) 
        super(initialState, middlewares);

    public function changeName(first : String, last : String) {
        update([
            state.person.firstName => name -> first == null ? name : first,
            state.person.lastName => name -> last == null ? name : last
        ]);
    }

    public function setScore(score : Int)
        update(state.score, score);

    public function updateFullState() {
        update(state, new DataClassState({
            score: 0, 
            person: new Person({
                firstName: "Hjalmar",
                lastName: "Schacht",
                created: Date.now()
            })
        }));
    }
}

class Recursive extends DeepState<RecursiveState> {
    public function new() super(null);
}

/////////////////////////////////////////////////////////////////////

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
        var asset2 : FBI;
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
        var nextState : TestState = {
            score: 1, 
            person: {
                name: { firstName: "Montagu", lastName: "Norman" }
            },
            timestamps: [Date.now()],
            json: { name: "Meitner", place: "Ljungaverk", year: 1945 }
        };

        var FBIstate = new DataClassState({
            person: new Person({
                firstName: "Peter", 
                lastName: "Wallenberg", 
                created: Date.now()
            })
        });

        beforeEach({
            asset = new CIA(initialState);
            asset2 = new FBI(FBIstate);
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

                var newState = asset.updateState({
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
                var newState = asset.updateState({type: 'test', updates: [
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
                var newState = asset.updateState({type: 'test', updates: [{ 
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
                var newState = asset.updateState({type: 'test', updates: [{ 
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
                var newState = asset.updateState({type: 'test', updates: [{ 
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
                var newState = asset.updateState({type: 'test_multiple', updates: [
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
                asset.updateState.bind({type: "test", updates: [{path: "some", value: "test"}]})
                    .should.throwType(String);

                asset.updateState.bind({type: "test", updates: [{path: "some.missing.field", value: 10}]})
                    .should.throwType(String);
            });

            it("should handle recursive typedefs", {
                var rec = new Recursive();
                rec.should.not.be(null);
            });

            /////////////////////////////////////////////////////////

            describe("The update method", {
                it("should use a lambda function to update a field if passed a function", {
                    asset.update(asset.state.score, score -> 1);
                    asset.update(asset.state.score, score -> score + 2);
                    asset.state.score.should.be(3);
                });

                it("should update fields when given a partial object", {
                    var newState = asset.update(asset.state.person.name, {firstName: "Marcus"}, "UpdateFirstName");

                    testIdentity(newState);
                    newState.person.name.firstName.should.be("Marcus");
                    newState.person.name.lastName.should.be("Enberg");

                    CompilationShould.failFor(
                        asset.update(asset.state.person.name, {firstName: 123})
                    );

                    CompilationShould.failFor(
                        asset.update(asset.state.person.name, {doesntExist: 123})
                    );
                });

                it("should update the whole field when given a complete object", {
                    var newState = asset.update(asset.state.person.name, {
                        firstName: "Marcus", lastName: "Wallenberg"
                    }, 'UpdateFullname');

                    testIdentity(newState);
                    newState.person.name.firstName.should.be("Marcus");
                    newState.person.name.lastName.should.be("Wallenberg");
                });

                it("should be able to update a field if passed a single value", {
                    var storeVar : CIA = asset;
                    var newState = storeVar.changeFirstName("Montagu");
                    //var newState = storeVar.update(storeVar.state.person.name.firstName, "Montagu");

                    CompilationShould.failFor(storeVar.update(storeVar.state.notAField, "Montagu"));

                    testIdentity(newState);
                    newState.score.should.be(0);
                    newState.person.name.firstName.should.be("Montagu");
                    newState.person.name.lastName.should.be("Enberg");
                });

                it("should update the whole state if specified", {
                    var newState = asset.update(asset.state, nextState, "FullUpdate");

                    newState.should.not.be(null);
                    newState.should.be(asset.state);
                    newState.timestamps[0].getTime().should.beGreaterThan(0);

                    newState.score.should.be(1);
                    newState.person.name.firstName.should.be("Montagu");
                    newState.person.name.lastName.should.be("Norman");
                });

                it("should update several values in one action if given a map", {
                    var newState = asset.update([
                        asset.state.score => score -> score + 3,
                        asset.state.person.name.lastName => "Dulles",
                        asset.state.person.name => {firstName: "John Foster"}
                    ], "UpdateSeveral");

                    testIdentity(newState);
                    newState.score.should.be(3);
                    newState.person.name.firstName.should.be("John Foster");
                    newState.person.name.lastName.should.be("Dulles");

                    CompilationShould.failFor(asset.update([1,2,3]));
                    CompilationShould.failFor(asset.update([a => "b"]));
                    CompilationShould.failFor(asset.update([asset.state.score => "not an int"]));
                });

                it("should unify between arguments for type safety", {
                    CompilationShould.failFor(asset.changeFirstName(123));
                });
            });

            describe("Class instantiation", {
                it("should create and update new objects with the data as parameter in the constructor", {
                    var currentState = asset2.state;
                    var currentPerson = currentState.person;

                    asset2.state.score.should.be(100);

                    asset2.changeName('Giuseppe', 'Volpi');

                    asset2.state.should.not.be(currentState);
                    asset2.state.person.should.not.be(currentPerson);

                    asset2.state.person.firstName.should.be("Giuseppe");
                    asset2.state.person.lastName.should.be("Volpi");

                    asset2.updateState({
                        type: 'Full',
                        updates: [{
                            path: '',
                            value: FBIstate
                        }]
                    });
                    asset2.state.should.be(currentState);

                    // This update should not collide with asset.update.
                    asset2.update(asset2.state, FBIstate);
                    asset2.state.should.be(currentState);
                });

                it("should be able to do a full state update from within the asset", {
                    asset2.updateFullState();
                    asset2.state.should.not.be(FBIstate);
                    asset2.state.person.firstName.should.be("Hjalmar");
                });

                it("should throw when validation fails for DataClass objects", {
                    asset2.setScore(1);
                    asset2.state.score.should.be(1);
                    (function() asset2.setScore(-100)).should.throwType(String);
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

            it("should be possible to specify action type by suppling a string as last argument, or null to use the calling method.", {
                asset.update(asset.state.score, 20, "Custom Score");

                logger.logs.length.should.be(1);
                logger.logs[0].type.should.be("Custom Score");

                asset.state.score.should.be(20);

                asset.update([asset.state.score => s -> s + 20], "Another custom");
                asset.update([asset.state.score => s -> s + 20], null);

                logger.logs.length.should.be(3);

                logger.logs[0].type.should.be("Custom Score");
                logger.logs[1].type.should.be("Another custom");
                logger.logs[2].type.should.be("DeepStateTests.new");

                asset.state.score.should.be(60);
            });
        });

        /////////////////////////////////////////////////////////////

        describe("Observables", {
            var obs : Observable<TestState>;
            var observedAsset : CIA;
            
            beforeEach({
                obs = new Observable<TestState>();
                observedAsset = new CIA(initialState, [obs.observe]);
            });

            describe("The subscribe method", {
                it("should subscribe to a part of the state tree", {
                    var newName : String = null;
                    var nameCalls = 0, lastNameCalls = 0;

                    var unsub = obs.subscribe(observedAsset.state.person.name, name -> {
                        newName = name.firstName + " " + name.lastName;
                        nameCalls++;
                    });

                    obs.subscribe(observedAsset.state.person.name.lastName, lastName -> {
                        lastNameCalls++;
                    });

                    observedAsset.changeFirstName("Avery");
                    newName.should.be("Avery Enberg");
                    nameCalls.should.be(1);
                    lastNameCalls.should.be(0);

                    observedAsset.changeFirstName("Avery");
                    nameCalls.should.be(2);
                    lastNameCalls.should.be(0);

                    observedAsset.update(observedAsset.state.person.name.lastName, "Dulles", "UpdateLastName");
                    observedAsset.state.person.name.lastName.should.be("Dulles");
                    newName.should.be("Avery Dulles");
                    nameCalls.should.be(3);
                    lastNameCalls.should.be(1);

                    unsub.closed.should.be(false);
                    unsub.unsubscribe();
                    unsub.closed.should.be(true);

                    observedAsset.changeFirstName("John Foster");
                    observedAsset.state.person.name.firstName.should.be("John Foster");
                    observedAsset.state.person.name.lastName.should.be("Dulles");
                    newName.should.be("Avery Dulles");
                    nameCalls.should.be(3);
                    lastNameCalls.should.be(1);                    
                });

                it("should subscribe with multiple checks if passed multiple methods", {
                    var newName : String = null;
                    var multiCalls = 0;

                    obs.subscribe(
                        observedAsset.state.person.name, observedAsset.state.score,
                        (name, score) -> {
                            newName = name.firstName + " " + name.lastName + ' ($score)';
                            multiCalls++;
                        }
                    );

                    observedAsset.changeFirstName("Avery");
                    newName.should.be("Avery Enberg (0)");
                    multiCalls.should.be(1);

                    observedAsset.update(observedAsset.state, nextState, "FullUpdate");

                    multiCalls.should.be(2);
                    observedAsset.state.score.should.be(1);
                    newName.should.be("Montagu Norman (1)");
                });

                it("should not compile if listener has incorrect number of arguments", {
                    CompilationShould.failFor(obs.subscribe(
                        observedAsset.state.person.name, observedAsset.state.score, 
                        (name) -> null
                    ));
                });

                it("should be able to subscribe to the whole state tree", {
                    obs.subscribe(
                        observedAsset.state, 
                        (state) -> state.score.should.be(0), 
                        observedAsset.state
                    );
                });

                it("should subscribe to the whole state if passing a function with two arguments", {
                    obs.subscribe((prev, current) -> {
                        prev.should.not.be(current);
                        prev.score.should.be(0);
                        current.score.should.be(1);
                    });

                    observedAsset.addScore(1);

                    var calledImmediately = -1;
                    obs.subscribe((prev, current) -> {
                        calledImmediately = current.score;
                    }, observedAsset.state);

                    calledImmediately.should.be(1);
                });

                it("should throw an exception when subscribing to a non-existing state field", {
                    function subscribeNonexistingPath() {
                        obs.subscribeObserver(Partial(["notExisting"], name -> null));
                        observedAsset.changeFirstName("Anything");
                    }

                    subscribeNonexistingPath.should.throwType(String);
                    CompilationShould.failFor(obs.subscribe(observedAsset.state.notExisting, name -> null));
                });

                it("should be able to immediately trigger the listener", {
                    var nameCalls = 0;

                    var unsub = obs.subscribe(observedAsset.state.person.name, name -> {
                        nameCalls++;
                    });

                    nameCalls.should.be(0);

                    obs.subscribe(observedAsset.state.person.name, name -> {
                        nameCalls++;
                    }, observedAsset.state);

                    nameCalls.should.be(1);
                });
            });
        });

        /////////////////////////////////////////////////////////////

        describe("Immutable datastructures", {
            describe("ImmutableMap", {
                it("should work with array access", {
                    var map = ["A" => 1];
                    var immutableMap : ImmutableMap<String, Int> = map;
                    var newMap = immutableMap.set("B", 2);

                    immutableMap.should.not.be(newMap);

                    [for(v in immutableMap.keys()) v].length.should.be(1);
                    immutableMap["A"].should.be(1);

                    [for(v in newMap.keys()) v].length.should.be(2);
                    immutableMap.should.not.be(newMap);
                });
            });

            describe("ImmutableArray", {
                it("should work with array access", {
                    var immutableArray : ImmutableArray<String> = ["A"];
                    immutableArray.length.should.be(1);
                    immutableArray[0].should.be("A");
                });

                it("should return a new array for the modification methods", {
                    var immutableArray : ImmutableArray<String> = ["A"];
                    var array2 = immutableArray.push("B");

                    array2.should.not.be(immutableArray);
                    array2.length.should.be(2);
                    array2[0].should.be("A");
                    array2[1].should.be("B");
                });

                it("should return the same array if nothing could be removed from it", {
                    var immutableArray : ImmutableArray<String> = ["A"];
                    immutableArray.remove("B").should.be(immutableArray);
                    immutableArray.remove("A").should.not.be(immutableArray);
                });

                it("should be able to access first and last elements with methods", {
                    var array = ["A", "B"];
                    var immutableArray : ImmutableArray<String> = array;

                    immutableArray.first().should.equal(Option.Some("A"));
                    immutableArray.last().should.equal(Option.Some("B"));

                    var empty : ImmutableArray<String> = [];
                    empty.first().should.equal(None);
                    empty.last().should.equal(None);
                });

                it("should be iterable", {
                    var immutableArray : ImmutableArray<String> = ["A", "B"];
                    var output = "";
                    for(a in immutableArray) output += a;
                    output.should.be("AB");
                });

                it("should work with a Lambda-like interface", {
                    var immutableArray : ImmutableArray<String> = ["A", "B"];
                    immutableArray.exists(a -> a == "A").should.be(true);
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

            describe("ImmutableJson", {
                it("should read values with get and array index", {
                    var startYear : Int = asset.state.json['years'].get('from');
                    startYear.should.be(1932);
                });

                it("should return the same json if nothing was removed", {
                    var list = asset.state.json;
                    list.remove("doesntExist").should.be(list);
                    list.remove("event").should.not.be(list);
                });

                it("should update as usual", {
                    var list = asset.state.json;
                    asset.update(asset.state, nextState, "FullUpdate");
                    asset.state.json.should.not.be(list);
                    (asset.state.json.get('place') : String).should.be("Ljungaverk");
                });
            });
        });
    }
}
