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
    public function new(initialState, middlewares = null) 
        super(initialState, middlewares);
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

        describe("The Deep State with -D deepstate-immutable-asset", {
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

        describe("Subscribers", {
            it("should not be available", {
                CompilationShould.failFor(asset.subscribeTo(
                    asset.state.score, (score) -> null
                ));
            });
        });
    }
}
