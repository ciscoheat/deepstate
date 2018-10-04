import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ExprTools;
using Reflect;
using Lambda;

private abstract DeepStateNode(Array<String>) from Array<String> {
    public inline function new(a : Array<String>) {
        if(a.length == 0) throw "DeepStateNode: Empty node list";
        this = a;
    }

    @:from
    public static function fromString(s : String) {
        return new DeepStateNode(s.split("."));
    }

    @:to
    public function toString() return this.join(".");

    public function hasNext() return this.length > 1;

    public function name() return this[0];

    public function next() : DeepStateNode
        if(!hasNext()) throw "DeepStateNode: No more nodes."
        else return this.slice(1);

    public function isNextLeaf()
        if(!hasNext()) throw "DeepStateNode: No more nodes."
        else return this.length == 2;
}

@:autoBuild(DeepStateInfrastructure.build())
class DeepState<T> {
    #if !macro
    public var state(default, null) : T;

    function new(initialState : T) {
        this.state = initialState;
    }

    public function updateState(newState : T) : T {
        // TODO: Apply middleware
        return this.state = newState;
    }

    public function update(updatePath : String, newValue : Any) : T {
        if(updatePath.length == 0) throw "Use Store.updateState for updating the whole state.";
        // TODO: Handle Dataclass (instad of state.copy)
        var copy = Reflect.copy(state);
        deepStateCopy(cast copy, updatePath, newValue);
        return updateState(copy);
    }

    function deepStateCopy(newState : haxe.DynamicAccess<Dynamic>, updatePath : DeepStateNode, newValue : Dynamic) : Void {
        var nodeName = updatePath.name();
        if(!newState.exists(nodeName)) throw "Key not found in state: " + updatePath;
        //trace('Updating: $updatePath');
        if(!updatePath.hasNext()) {
            //trace('updating $nodeName and finishing.');
            newState.set(nodeName, newValue);
        } else {
            var copy = Reflect.copy(newState.get(nodeName));            
            newState.set(nodeName, copy);
            deepStateCopy(copy, updatePath.next(), newValue);
        }
    }
    #end

    macro public function updateIn(store : ExprOf<DeepState<Dynamic>>, path : Expr, newValue : Expr) {
        var t1 = Context.typeof(path);
        var t2 = Context.typeof(newValue);
        
        var pathStr = path.toString();

        trace("=== " + pathStr);

        // Strip "store.state." from path
        for(v in Context.getLocalTVars()) {
            if(pathStr.indexOf('${v.name}.state.') == 0) {
                pathStr = pathStr.substr(v.name.length + 7);
                break;
            }
        }

        if(Context.unify(t1, t2)) {
            trace("Types unifies.");
            return macro $store.update($v{pathStr}, $newValue);
        }

        switch t1 {
            case TAnonymous(a):
                trace("Anonymous with fields [" + a.get().fields.map(f -> f.name).join(", ") + "]");
                var t3 = Context.getType("Store.TestState_Vars_name");
                trace("Unifies with var version: " + Context.unify(t3, t2));
            case _:
                trace("Unknown: " + t1);
        }

        return path;
    }
}
