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

class TestStateStore extends DeepState<TestState> {
    public function new(initialState) super(initialState);
}

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

                newState.should.be(store.state);

                newState.should.not.be(null);
                newState.score.should.be(1);
                newState.person.name.firstName.should.be("Allan");
                newState.person.name.lastName.should.be("Benberg");
            });

            it("should update fields in the middle of the state tree", {
                var newState = store.update("person.name", {
                    firstName: "Allan", lastName: "Benberg"
                });

                newState.should.be(store.state);
                newState.should.not.be(null);
                newState.should.not.be(initialState);
                newState.score.should.be(0);
                newState.person.name.firstName.should.be("Allan");
                newState.person.name.lastName.should.be("Benberg");
            });

            it("should update fields at the end of the state tree", {
                var newState = store.update("person.name.firstName", "Wallan");

                newState.should.be(store.state);
                newState.should.not.be(null);
                newState.should.not.be(initialState);
                newState.score.should.be(0);
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

                newState.should.be(store.state);
                newState.should.not.be(null);
                newState.should.not.be(initialState);
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
        });
    }
}
