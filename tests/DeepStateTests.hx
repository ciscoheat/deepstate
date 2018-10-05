import buddy.CompilationShould;

using buddy.Should;

typedef TestState = {
    final score : Int;
    final person : {
        final name : {
            final firstName : String;
            final lastName : String;
        }
    }
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
}

class DataClassStore extends DeepState<DataClassState> {
    public function new(initialState) super(initialState);
}

///////////////////////////////////////////////////////////

class DeepStateTests extends buddy.SingleSuite {
    public function new() {
        describe("The Deep State", {
            var store : TestStateStore;
            var initialState : TestState = {
                score: 0,
                person: {
                    name: { firstName: "Wall", lastName: "Enberg"}
                }
            };

            function testIdentity(newState : TestState) {
                newState.should.be(store.state);
                newState.should.not.be(null);
                newState.should.not.be(initialState);
            }

            beforeEach({
                store = new TestStateStore(initialState);
            });

            it("should replace the previous state when calling updateState", {
                var nextState : TestState = {
                    score: 1, 
                    person: {
                        name: {
                            firstName: "Allan", lastName: "Benberg"
                        }
                    }
                };

                CompilationShould.failFor(
                    store.state = nextState
                );

                var newState = store.updateState(nextState);

                newState.should.not.be(null);
                newState.should.be(store.state);

                newState.score.should.be(1);
                newState.person.name.firstName.should.be("Allan");
                newState.person.name.lastName.should.be("Benberg");
            });

            it("should update fields in the middle of the state tree", {
                var newState = store.update("person.name", {
                    firstName: "Allan", lastName: "Benberg"
                });

                testIdentity(newState);
                newState.score.should.be(0);
                newState.person.should.not.be(initialState.person);
                newState.person.name.firstName.should.be("Allan");
                newState.person.name.lastName.should.be("Benberg");
            });

            it("should update fields at the end of the state tree", {
                var newState = store.update("person.name.firstName", "Wallan");

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
                var newState = store.update("score", 10);

                testIdentity(newState);
                newState.score.should.be(10);
                newState.person.name.firstName.should.be("Wall");
                newState.person.name.lastName.should.be("Enberg");
            });

            it("should not allow empty string as field key", {
                store.update.bind("", initialState).should.throwType(String);
            });

            it("should throw if a field key doesn't exist in the state tree", {
                store.update.bind("some", "test").should.throwType(String);
                store.update.bind("some.missing.field", 10).should.throwType(String);
            });

            describe("The updateIn method", {
                it("should not be able to update the whole state", {
                    (function() { 
                        var storeVar : TestStateStore = store;
                        storeVar.updateIn(storeVar.state, initialState); 
                    }).should.throwType(String);
                });

                it("should macro for type safety", {
                    var storeVar : TestStateStore = store;
                    var newState = storeVar.updateIn(storeVar.state.person.name.firstName, "Allan");

                    testIdentity(newState);
                    newState.score.should.be(0);
                    newState.person.name.firstName.should.be("Allan");
                    newState.person.name.lastName.should.be("Enberg");
                });

                it("should unify between arguments for type safety", {
                    var storeVar : TestStateStore = store;
                    CompilationShould.failFor(storeVar.updateIn(storeVar.state.score, "Not an Int"));
                });
            });
        });
    }
}
