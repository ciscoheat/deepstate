import haxe.macro.Type.AbstractType;
import haxe.DynamicAccess;
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ExprTools;
using haxe.macro.Tools;
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

    function deepStateCopy(newState : DynamicAccess<Dynamic>, updatePath : DeepStateNode, newValue : Any) : Void {
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
        // TODO: Error handling for failed typeof calls.
        var t1 = Context.typeof(path);

        try {
            var type = Context.toComplexType(t1);
            Context.typeof(macro var test : $type = $newValue); 
        } catch(e : Dynamic) {
            Context.error("Value should be " + t1.toString(), newValue.pos);
        }

        var pathStr = path.toString();
        // Strip "store.state" from path
        for(v in Context.getLocalTVars()) {
            var pathTest = '${v.name}.state';
            if(pathTest == pathStr) {
                // Let update handle the error check
                pathStr = "";
                break;
            }
            else if(pathStr.indexOf('$pathTest.') == 0) {
                pathStr = pathStr.substr(pathTest.length + 1);
                break;
            }
        }

        return macro $store.update($v{pathStr}, $newValue);
    }
}
