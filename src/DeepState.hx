import haxe.DynamicAccess;
import haxe.macro.Context;
import haxe.macro.Expr;

import ds.ImmutableArray;

using haxe.macro.Tools;
using Reflect;

typedef Action = {
    final name : String;
    final updates : ImmutableArray<{
        final path : String;
        final value : Dynamic;
    }>;
}

private abstract DeepStateNode(ImmutableArray<String>) {
    public inline function new(a : ImmutableArray<String>) {
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
        else return new DeepStateNode(this.slice(1));

    public function isNextLeaf()
        if(!hasNext()) throw "DeepStateNode: No more nodes."
        else return this.length == 2;
}

@:autoBuild(ds.internal.DeepStateInfrastructure.build())
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

    public function update(action : Action) : T {
        // TODO: Handle Dataclass (create a copy method based on type)
        var copy = Reflect.copy(state);
        for(a in action.updates)
            deepStateCopy(cast copy, a.path, a.value);
        return updateState(copy);
    }

    function deepStateCopy(newState : DynamicAccess<Dynamic>, updatePath : DeepStateNode, newValue : Any) : Void {
        var nodeName = updatePath.name();
        if(nodeName.length == 0) throw "Use Store.updateState for updating the whole state.";
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
        var t1 = try Context.typeof(path)
        catch(e : Dynamic) {
            Context.error("Cannot find state type, please provide a type hint.", path.pos);
        }

        try {
            var type = Context.toComplexType(t1);
            Context.typeof(macro var _DStest : $type = $newValue); 
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

        var actionName = Context.getLocalMethod();

        return macro $store.update({
            name: $v{actionName},
            updates: [{
                path: $v{pathStr},
                value: $newValue
            }]
        });
    }
}
