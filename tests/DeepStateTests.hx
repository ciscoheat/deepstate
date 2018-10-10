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

class TestStateStore extends DeepState<TestState> {
    public function new(initialState) super(initialState);

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

///////////////////////////////////////////////////////////

class DeepStateTests extends buddy.SingleSuite {
    public function new() {
        describe("The Deep State", {
            var store : TestStateStore;
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
                        firstName: "Allan", lastName: "Benberg"
                    }
                },
                timestamps: [Date.now()]
            };

            function testIdentity(newState : TestState) {
                newState.should.be(store.state);
                newState.should.not.be(null);
                newState.should.not.be(initialState);
            }

            beforeEach({
                store = new TestStateStore(initialState);
            });

            it("should update the whole state if specified", {
                CompilationShould.failFor(
                    store.state = nextState
                );

                var newState = store.update({
                    type: "full_update", 
                    updates: [{path: "", value: nextState}]
                });

                newState.should.not.be(null);
                newState.should.be(store.state);
                newState.timestamps[0].getTime().should.beGreaterThan(0);

                newState.score.should.be(1);
                newState.person.name.firstName.should.be("Allan");
                newState.person.name.lastName.should.be("Benberg");
            });

            it("should not modify the first state object when multiple changes are made", {
                var newState = store.update({type: 'test', updates: [
                    { 
                        path: "", 
                        value: nextState
                    },
                    { 
                        path: "person.name", 
                        value: { firstName: "Allen", lastName: "Dulles" }
                    }
                ]});

                testIdentity(newState);
                newState.score.should.be(1);
                newState.person.should.not.be(initialState.person);
                newState.person.name.firstName.should.be("Allen");
                newState.person.name.lastName.should.be("Dulles");

                nextState.should.not.be(newState);
                nextState.person.name.firstName.should.be("Allan");
                nextState.person.name.lastName.should.be("Benberg");
            });

            it("should update fields in the middle of the state tree", {
                var newState = store.update({type: 'test', updates: [{ 
                    path: "person.name", 
                    value: { firstName: "Allan", lastName: "Benberg" }
                }]});

                testIdentity(newState);
                newState.score.should.be(0);
                newState.person.should.not.be(initialState.person);
                newState.person.name.firstName.should.be("Allan");
                newState.person.name.lastName.should.be("Benberg");
            });

            it("should update fields at the end of the state tree", {
                var newState = store.update({type: 'test', updates: [{ 
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
                    store.state.person.name.firstName = "Ture"
                );
            });

            it("should update fields at the top of the state tree", {
                var newState = store.update({type: 'test', updates: [{ 
                    path: "score", 
                    value: 10
                }]});

                testIdentity(newState);
                newState.score.should.be(10);
                newState.person.name.firstName.should.be("Wall");
                newState.person.name.lastName.should.be("Enberg");

                var newState2 = store.addScore(20);
                newState2.should.not.be(newState);
                newState2.score.should.be(30);
            });

            it("should update several fields if specified in the Action", {
                var timestamps = store.state.timestamps;
                var newState = store.update({type: 'test_multiple', updates: [
                    { path: "score", value: 100 },
                    { path: "person.name.lastName", value: "Benberg" },
                    { path: "timestamps", value: timestamps.push(Date.now()) }
                ]});

                testIdentity(newState);
                newState.score.should.be(100);

                newState.person.name.firstName.should.be("Wall");
                newState.person.name.lastName.should.be("Benberg");

                newState.timestamps.length.should.be(1);
                newState.timestamps.should.not.be(timestamps);
            });

            it("should throw if a field key doesn't exist in the state tree", {
                store.update.bind({type: "test", updates: [{path: "some", value: "test"}]})
                    .should.throwType(String);

                store.update.bind({type: "test", updates: [{path: "some.missing.field", value: 10}]})
                    .should.throwType(String);
            });

            /////////////////////////////////////////////////////////

            describe("The updateIn method", {
                it("should use a lambda function to update a field if passed a function", {
                    store.updateIn(store.state.score, score -> 1);
                    store.updateIn(store.state.score, score -> score + 2);
                    store.state.score.should.be(3);
                });

                it("should update fields when given a partial object", {
                    var newState = store.updateIn(store.state.person.name, {firstName: "Marcus"});

                    testIdentity(newState);
                    newState.person.name.firstName.should.be("Marcus");
                    newState.person.name.lastName.should.be("Enberg");

                    CompilationShould.failFor(
                        store.updateIn(store.state.person.name, {firstName: 123})
                    );

                    CompilationShould.failFor(
                        store.updateIn(store.state.person.name, {doesntExist: 123})
                    );
                });

                it("should update the whole field when given a complete object", {
                    var newState = store.updateIn(store.state.person.name, {
                        firstName: "Marcus", lastName: "Wallenberg"
                    });

                    testIdentity(newState);
                    newState.person.name.firstName.should.be("Marcus");
                    newState.person.name.lastName.should.be("Wallenberg");
                });

                it("should be able to update a field if passed a single value", {
                    var storeVar : TestStateStore = store;
                    var newState = storeVar.changeFirstName("Allan");
                    //var newState = storeVar.updateIn(storeVar.state.person.name.firstName, "Allan");

                    CompilationShould.failFor(storeVar.updateIn(storeVar.state.notAField, "Allan"));

                    testIdentity(newState);
                    newState.score.should.be(0);
                    newState.person.name.firstName.should.be("Allan");
                    newState.person.name.lastName.should.be("Enberg");
                });

                it("should update the whole state if specified", {
                    var newState = store.updateIn(store.state, nextState);

                    newState.should.not.be(null);
                    newState.should.be(store.state);
                    newState.timestamps[0].getTime().should.beGreaterThan(0);

                    newState.score.should.be(1);
                    newState.person.name.firstName.should.be("Allan");
                    newState.person.name.lastName.should.be("Benberg");
                });

                it("should update several values in one action if given a map", {
                    var newState = store.updateMap([
                        store.state.score => score -> score + 3,
                        store.state.person.name.lastName => "Dulles",
                        store.state.person.name => {firstName: "John Foster"}
                    ]);

                    testIdentity(newState);
                    newState.score.should.be(3);
                    newState.person.name.firstName.should.be("John Foster");
                    newState.person.name.lastName.should.be("Dulles");

                    CompilationShould.failFor(store.updateMap([1,2,3]));
                    CompilationShould.failFor(store.updateMap([a => "b"]));
                    CompilationShould.failFor(store.updateMap([store.state.score => "not an int"]));
                });

                it("should unify between arguments for type safety", {
                    CompilationShould.failFor(store.changeFirstName(123));
                });
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
