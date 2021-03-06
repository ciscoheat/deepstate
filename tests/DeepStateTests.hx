import haxe.ds.Option;
import buddy.CompilationShould;
import ds.ImmutableArray;
import ds.ImmutableJson;
import ds.ImmutableList;
import ds.ImmutableMap;
import ds.Observable;
import ds.Action;

import haxe.macro.Expr;
import haxe.Constraints;

using buddy.Should;
using ds.MiddlewareAccess;

typedef Name = {
    final firstName : String;
    final lastName : String;
}

typedef TestState = {
    final score : Int;
    final person : {
        final name : Name;
        final tags : ImmutableArray<{
            final name : String;
        }>;
        final stuff : ImmutableMap<String, { 
            final priority : Int; 
        }>;
    }
    final timestamps : ImmutableArray<Date>;
    final json : ImmutableJson;
}

///////////////////////////////////////////////////////////

enum AltTest {
	AltA;
	AltB;
}

typedef AltState = {
    final test : AltTest;
    final name : String;
}

////////////////////////////////////////////////////////////

enum Color<T> {
    Black(a : ImmutableArray<String>);
    White(b : T);
}

typedef Chessboard = {
    final board : ImmutableArray<ImmutableArray<{
        final color : Color<Int>; 
        final piece : String;
    }>>;
    final players : {
        final white : String;
        final black : String;
    }
}

///////////////////////////////////////////////////////////

typedef AgeName = {
	final age : Int;
	final name : String;
}

class AgeNameContainer extends DeepStateContainer<AgeName> {}

///////////////////////////////////////////////////////////

typedef RecursiveState = {
    final node : RecursiveState;
    final value : String;
}

///////////////////////////////////////////////////////////

typedef DefaultState = {
    final score : Int;
    final person : {
        final name : {
            final firstName : String;
            final lastName : String;
        }
    }
    final date : Date;
    final floats : ImmutableArray<Float>;
}

///////////////////////////////////////////////////////////

class Person implements DataClass {
    public final firstName : String;
    public final lastName : String;
    public final created : Date;

    public function name() return '$firstName $lastName';
}

class DataClassState implements DataClass {
    @:validate(_ >= 0)
    public final score : Int = 100;
    public final person : Person;
}

///////////////////////////////////////////////////////////

class CIA {
    public static function addScore(asset : DeepState<TestState>, add : Int) {
        return asset.update(asset.state.score = asset.state.score + add);
    }

    public static function changeFirstName(asset : DeepState<TestState>, firstName) {
        return asset.update(asset.state.person.name.firstName = firstName);
    }
}

class FBI {
    public static function changeName(asset : DeepState<DataClassState>, first : String, last : String) {
        return asset.update(
            asset.state.person.firstName = name -> first == null ? name : first,
            asset.state.person.lastName = name -> last == null ? name : last
        );
    }

    public static function setScore(asset : DeepState<DataClassState>, score : Int)
        return asset.update(asset.state.score = score);

    public static function updateFullState(asset : DeepState<DataClassState>) {
        return asset.update(asset.state = new DataClassState({
            score: 0, 
            person: new Person({
                firstName: "Hjalmar",
                lastName: "Schacht",
                created: Date.now()
            })
        }));
    }
}

/////////////////////////////////////////////////////////////////////

class MiddlewareLog<T> {
    public function new() {}

    public static var logCount = new Array<String>();

    public var logs(default, null) = new Array<{state: T, type: String}>();

    public function log(asset: ds.gen.DeepState<T>, next : Action -> ds.gen.DeepState<T>, action : Action) : ds.gen.DeepState<T> {
        var nextState = next(action);
        logs.push({state: nextState.state, type: action.type});
        logCount.push("MiddlewareLog");
        return nextState;
    }
}

class MiddlewareAlert {
    public function new() {}

    public var alerts(default, null) = 0;

    public function alertOn(actionType : String) {
        return function(asset: Dynamic, next : Action -> Dynamic, action : Action) {
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
        var asset : DeepState<TestState>;
        var asset2 : DeepState<DataClassState>;

        var initialState : TestState = {
            score: 0,
            person: {
                name: { firstName: "Wall", lastName: "Enberg" },
                tags: [{name: "Boliden"}, {name: "IG"}],
                stuff: ["Ljungaverk" => {priority: 10}]
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
                name: { firstName: "Montagu", lastName: "Norman" },
                tags: [{name: "Ring"}],
                stuff: ["Ljungaverk" => {priority: 10}]
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
            asset = new DeepState<TestState>(initialState);
            asset2 = new DeepState<DataClassState>(FBIstate);
        });

        describe("The Deep State", {
            function testIdentity(newState : DeepState<TestState>) {
                newState.should.not.be(null);
                newState.should.not.be(asset);
                newState.state.should.not.be(null);
                newState.state.should.not.be(asset.state);
                newState.state.should.not.be(initialState);
            }

            it("should be possible to instantiate a DeepState object with a type parameter", {
                var a = new DeepState<TestState>(initialState);
                a.state.person.name.firstName.should.be("Wall");
                a = a.update(a.state.person.name.firstName = "Walle", "DSInstantiation");
                a.state.person.name.firstName.should.be("Walle");                
            });

            it("should throw if initial state is null", {
                (function() new DeepState<TestState>(null)).should.throwType(String);
            });

            it("should update the whole state if specified", {
                CompilationShould.failFor(
                    asset.state = nextState
                );

                var newState = asset.update(asset.state = nextState, "FullUpdate");

                newState.state.should.not.be(null);
                newState.state.should.be(nextState);
                newState.state.timestamps[0].getTime().should.beGreaterThan(0);
                newState.state.score.should.be(1);
                newState.state.person.name.firstName.should.be("Montagu");
                newState.state.person.name.lastName.should.be("Norman");
            });

            it("should not modify the first state object when multiple changes are made", {
                var newState = asset.update(
                    asset.state = nextState,
                    asset.state.person.name = { firstName: "Avery", lastName: "Dulles" }
                , "MultipleUpdates");

                testIdentity(newState);
                newState.state.score.should.be(1);
                newState.state.person.should.not.be(initialState.person);
                newState.state.person.name.firstName.should.be("Avery");
                newState.state.person.name.lastName.should.be("Dulles");

                nextState.should.not.be(newState);
                nextState.person.name.firstName.should.be("Montagu");
                nextState.person.name.lastName.should.be("Norman");
            });

            it("should update fields in the middle of the state tree", {
                var newState = asset.update(
                    asset.state.person.name = { firstName: "Montagu", lastName: "Norman" },
                    "NameUpdate"
                );

                testIdentity(newState);
                newState.state.score.should.be(0);
                newState.state.person.should.not.be(initialState.person);
                newState.state.person.name.firstName.should.be("Montagu");
                newState.state.person.name.lastName.should.be("Norman");
            });

            it("should update fields at the end of the state tree", {
                var newState = asset.update(asset.state.person.name.firstName = "Wallan", "FirstNameUpdate");

                testIdentity(newState);
                newState.state.score.should.be(0);
                newState.state.person.should.not.be(initialState.person);
                newState.state.person.name.firstName.should.be("Wallan");
                newState.state.person.name.lastName.should.be("Enberg");
                
                CompilationShould.failFor(
                    newState.state.person.name.firstName = "Ture"
                );

                CompilationShould.failFor(
                    asset.state.person.name.firstName = "Ture"
                );
            });

            it("should update fields at the top of the state tree", {
                var newState = asset.update(asset.state.score = 10, "ScoreUpdate");

                testIdentity(newState);
                newState.state.score.should.be(10);
                newState.state.person.name.firstName.should.be("Wall");
                newState.state.person.name.lastName.should.be("Enberg");

                var newState2 = CIA.addScore(newState, 20);
                newState2.state.should.not.be(newState.state);
                newState2.state.score.should.be(30);
            });

            it("should update several fields through a Map in the Action", {
                var timestamps = asset.state.timestamps;
                var newState = asset.update(
                    asset.state.score = 100,
                    asset.state.person.name.lastName = "Norman",
                    asset.state.timestamps = timestamps.push(Date.now())
                , 'test_multiple_map');

                testIdentity(newState);
                newState.state.score.should.be(100);

                newState.state.person.name.firstName.should.be("Wall");
                newState.state.person.name.lastName.should.be("Norman");

                newState.state.timestamps.length.should.be(1);
                newState.state.timestamps.should.not.be(timestamps);
            });

            it("should update several fields through assignment in the Action", {
                var timestamps = asset.state.timestamps;
                var newState = asset.update(
                    asset.state.score = 100,
                    asset.state.person.name.lastName = "Norman"
                , 'test_multiple_assignment');

                testIdentity(newState);
                newState.state.score.should.be(100);

                newState.state.person.name.firstName.should.be("Wall");
                newState.state.person.name.lastName.should.be("Norman");
            });

            it("should handle deep recursive updates", {
                var rec = new DeepState<RecursiveState>({node: {node: {node: null, value: "3"}, value: "2"}, value: "1"});
                rec.state.node.node.value.should.be("3");
                var next = rec.update(rec.state.node.node.value = "A", "DeepRecursiveUpdate");
                next.state.node.value.should.be("A");
            });

            /////////////////////////////////////////////////////////

            describe("The update method", {
                /*
                it("should be possible to refer to the state with a shorthand '_' var", {
                    var next = asset.update(_.person.name.firstName = "Andre", "ShorthandUpdate");
                    next.state.person.name.firstName.should.be("Andre");
                    next = next.update(_.person.name.firstName = "Oscar", "ShorthandUpdate");
                    next.state.person.name.firstName.should.be("Oscar");
                });
                */

                it("should use a lambda function to update a field if passed a function", {
                    var next = asset.update(asset.state.score = score -> 1);
                    next = next.update(next.state.score = score -> score + 2, "LambdaUpdate");
                    next.state.score.should.be(3);
                });

                it("should update fields when given a partial object", {
                    var newState = asset.update(asset.state.person.name = {firstName: "Marcus"}, "UpdateFirstName");

                    testIdentity(newState);
                    newState.state.person.name.firstName.should.be("Marcus");
                    newState.state.person.name.lastName.should.be("Enberg");

                    CompilationShould.failFor(
                        asset.update(asset.state.person.name, {firstName: 123})
                    );

                    CompilationShould.failFor(
                        asset.update(asset.state.person.name, {doesntExist: 123})
                    );
                });

                it("should update the whole field when given a complete object", {
                    var newState = asset.update(asset.state.person.name = {
                        firstName: "Marcus", lastName: "Wallenberg"
                    }, 'UpdateFullname');

                    testIdentity(newState);
                    newState.state.person.name.firstName.should.be("Marcus");
                    newState.state.person.name.lastName.should.be("Wallenberg");
                });

                it("should be able to update a field if passed a single value", {
                    var storeVar : DeepState<TestState> = asset;
                    var newState = CIA.changeFirstName(storeVar, "Montagu");

                    CompilationShould.failFor(storeVar.update(storeVar.state.notAField, "Montagu"));

                    testIdentity(newState);
                    newState.state.score.should.be(0);
                    newState.state.person.name.firstName.should.be("Montagu");
                    newState.state.person.name.lastName.should.be("Enberg");
                });

                it("should update the whole state if specified", {
                    var newState = asset.update(asset.state = nextState, "FullUpdate");

                    newState.state.should.not.be(null);
                    newState.state.should.not.be(asset.state);
                    newState.state.timestamps[0].getTime().should.beGreaterThan(0);

                    newState.state.score.should.be(1);
                    newState.state.person.name.firstName.should.be("Montagu");
                    newState.state.person.name.lastName.should.be("Norman");
                });

                it("should update several values in one action if given a map", {
                    var newState = asset.update(
                        asset.state.score = score -> score + 3,
                        asset.state.person.name.lastName = "Dulles",
                        asset.state.person.name = {firstName: "John Foster"}
                    , "UpdateSeveral");

                    testIdentity(newState);
                    newState.state.score.should.be(3);
                    newState.state.person.name.firstName.should.be("John Foster");
                    newState.state.person.name.lastName.should.be("Dulles");

                    CompilationShould.failFor(asset.update([1,2,3]));
                    CompilationShould.failFor(asset.update(a = "b"));
                    CompilationShould.failFor(asset.update(asset.state.score = "not an int"));
                });

                it("should unify between arguments for type safety", {
                    CompilationShould.failFor(CIA.changeFirstName(asset, 123));
                });

                it("should handle array access for ImmutableArrays", {
                    var next : DeepState<TestState> = asset.update(asset.state.person.tags[0].name = "Tagged", "ArrayUpdate");
                    next.state.person.tags.length.should.be(2);
                    next.state.person.tags[0].name.should.be("Tagged");
                    next.state.person.tags[1].name.should.be("IG");
                });

                it("should handle simple enums", {
                    var alt = new DeepState<AltState>({
                        test: AltTest.AltA,
                        name: "Artelius"
                    });
                    alt.state.test.should.equal(AltA);
                    alt.state.name.should.be("Artelius");
                });

                it("should handle multi-dimensional array access for ImmutableArrays", {
                    var chess = new DeepState<Chessboard>({
                        board: [
                            [{color: White(1), piece: "R"},{color: Black(["2"]), piece: "N"}],
                            [{color: White(3), piece: "p"}]
                        ],
                        players: {black: "Kassman", white: "Aschberg"}
                    });
                    var next = chess.update(chess.state.board[1][0].piece = "Q");
                    next.state.board[1][0].piece.should.be("Q");
                });

                it("should handle map access for ImmutableMaps", {
                    asset.state.person.stuff["Ljungaverk"].priority.should.be(10);
                    var next = asset.update(asset.state.person.stuff["Ljungaverk"].priority = 11, "MapUpdate");

                    next.state.person.stuff["Ljungaverk"].priority.should.be(11);
                    asset.state.person.stuff.should.not.be(next.state.person.stuff);
                });
            });

            describe("Class instantiation", {
                it("should create and update new objects with the data as parameter in the constructor", {
                    var currentState = asset2.state;
                    var currentPerson = currentState.person;

                    asset2.state.score.should.be(100);

                    var next : DeepState<DataClassState>  = FBI.changeName(asset2, 'Giuseppe', 'Volpi');

                    next.state.should.not.be(currentState);
                    next.state.person.should.not.be(currentPerson);

                    next.state.person.firstName.should.be("Giuseppe");
                    next.state.person.lastName.should.be("Volpi");

                    next = next.update(next.state = FBIstate, "FBIUpdate");
                    next.state.should.be(currentState);

                    // This update should not collide with asset.update.
                    next = next.update(next.state = FBIstate, "FBIUpdate");
                    next.state.should.be(currentState);
                });

                it("should be able to do a full state update from within the asset", {
                    var next = FBI.updateFullState(asset2);
                    next.state.should.not.be(FBIstate);
                    next.state.person.firstName.should.be("Hjalmar");
                });

                it("should throw when validation fails for DataClass objects", {
                    var next = FBI.setScore(asset2, 1);
                    next.state.score.should.be(1);
                    (function() FBI.setScore(next, -100)).should.throwType(dataclass.DataClassException);
                });
            });
        });

        /////////////////////////////////////////////////////////////

        describe("Middleware", {
            var logger : MiddlewareLog<TestState>;
            var alert : MiddlewareAlert;

            beforeEach({
                logger = new MiddlewareLog();
                alert = new MiddlewareAlert();
                asset = new DeepState<TestState>(initialState, [
                    logger.log, 
                    alert.alertOn("CIA.addScore")
                ]);
                MiddlewareLog.logCount = [];
            });

            it("should be applied in the correct order", {
                var next = CIA.addScore(asset, 10);

                logger.logs.length.should.be(1);
                logger.logs[0].type.should.be("CIA.addScore");
                logger.logs[0].state.score.should.be(10);

                alert.alerts.should.be(1);

                MiddlewareLog.logCount.should.containExactly(["MiddlewareAlert", "MiddlewareLog"]);

                next.state.score.should.be(10);
            });

            it("should be possible to specify action type by suppling a string as last argument, or null to use the calling method.", {
                var next = asset.update(asset.state.score = 20, "Custom Score");

                logger.logs.length.should.be(1);
                logger.logs[0].type.should.be("Custom Score");

                next.state.score.should.be(20);

                next = next.update(next.state.score = s -> s + 20, "Another custom");
                next = next.update(next.state.score = s -> s + 20, null);

                logger.logs.length.should.be(3);

                logger.logs[0].type.should.be("Custom Score");
                logger.logs[1].type.should.be("Another custom");
                logger.logs[2].type.should.be("DeepStateTests.new");

                next.state.score.should.be(60);
            });
        });

        /////////////////////////////////////////////////////////////

        describe("Observables", {
            var obs : Observable<TestState>;
            var observedAsset : DeepState<TestState>;
            
            beforeEach({
                obs = new Observable<TestState>();
                observedAsset = new DeepState<TestState>(initialState, [obs.observe]);
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

                    var next = CIA.changeFirstName(observedAsset, "Avery");
                    newName.should.be("Avery Enberg");
                    nameCalls.should.be(1);
                    lastNameCalls.should.be(0);

                    next = CIA.changeFirstName(next, "Avery");
                    nameCalls.should.be(2);
                    lastNameCalls.should.be(0);

                    next = next.update(next.state.person.name.lastName = "Dulles", "UpdateLastName");
                    next.state.person.name.lastName.should.be("Dulles");
                    newName.should.be("Avery Dulles");
                    nameCalls.should.be(3);
                    lastNameCalls.should.be(1);

                    unsub.closed.should.be(false);
                    unsub.unsubscribe();
                    unsub.closed.should.be(true);

                    next = CIA.changeFirstName(next, "John Foster");
                    next.state.person.name.firstName.should.be("John Foster");
                    next.state.person.name.lastName.should.be("Dulles");
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

                    CIA.changeFirstName(observedAsset, "Avery");
                    newName.should.be("Avery Enberg (0)");
                    multiCalls.should.be(1);

                    var next = observedAsset.update(observedAsset.state = nextState, "FullUpdate");

                    multiCalls.should.be(2);
                    next.state.score.should.be(1);
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

                    var next = CIA.addScore(observedAsset, 1);

                    var calledImmediately = -1;
                    obs.subscribe((prev, current) -> {
                        calledImmediately = current.score;
                    }, next.state);

                    calledImmediately.should.be(1);
                });

                it("should throw an exception when subscribing to a non-existing state field", {
                    function subscribeNonexistingPath() {
                        obs.subscribeObserver(Partial(["notExisting"], name -> null));
                        CIA.changeFirstName(observedAsset, "Anything");
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
                    var next = asset.update(asset.state = nextState, "FullUpdate");
                    next.state.json.should.not.be(list);
                    (next.state.json.get('place') : String).should.be("Ljungaverk");
                });
            });
        });

        /////////////////////////////////////////////////////////////

        describe("DeepStateContainer", {
            it("should contain a mutable asset and an observable", {
                var container = new AgeNameContainer(new DeepState<AgeName>({name: "", age: 0}));
                var ages : Array<Int> = [];

                container.state.age.should.be(0);

                container.subscribe(container.state.age, age -> {
                    // Test if container has updated before observable
                    container.state.age.should.be(age);
                    ages.push(age);
                });

                container.update(container.state.age = age -> age + 10);
                container.state.age.should.be(10);

                container.update(container.state.age = age -> age + 10);
                container.state.age.should.be(20);

                ages.should.containExactly([10,20]);
            });

            it("should be able to enclose a container that updates its parent and vice versa", {
                var log = new Array<String>();
                var container = new DeepStateContainer<TestState>(asset);

                container.subscribe(container.state.person.name.lastName, lastName -> log.push(lastName));
                container.update(container.state.person.name.lastName = "Dulles");
                container.state.person.name.lastName.should.be("Dulles");

                log.length.should.be(1);
                log[0].should.be("Dulles");

                // A typedef must exist, cannot create directly from an anonymous type.
                CompilationShould.failFor(container.enclose(container.state.person));

                var sub = container.enclose(container.state.person.name);

                sub.update(sub.state.lastName = "Duisberg", "EnclosureUpdate");
                container.state.person.name.lastName.should.be("Duisberg");
                sub.state.lastName.should.be("Duisberg");
                log.length.should.be(2);
                log[1].should.be("Duisberg");

                container.update(container.state.person.name.lastName = "Schacht");
                container.state.person.name.lastName.should.be("Schacht");
                sub.state.lastName.should.be("Schacht");
                log.length.should.be(3);
                log[2].should.be("Schacht");
            });
        });
    }
}
