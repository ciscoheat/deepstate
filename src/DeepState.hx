import haxe.macro.Type.AbstractType;
import haxe.DynamicAccess;
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ExprTools;
using haxe.macro.Tools;
using Reflect;
using Lambda;

@:forward(length, concat, join, toString, indexOf, lastIndexOf, copy, iterator, map, filter)
abstract ImmutableArray<T>(Array<T>) from Array<T> to Iterable<T> {
	@:arrayAccess @:extern inline public function arrayAccess(key:Int):T return this[key];
}

@:forward(filter, first, isEmpty, iterator, join, last, map, toString)
abstract ImmutableList<T>(List<T>) from List<T> to Iterable<T> {
    public function add(item : T) : ImmutableList<T> {
        var newList = this.filter(i -> true);
        newList.add(item);
        return newList;
    }
    // TODO: Remove, etc...
}

/*
@:forward(exists, get, iterator, keys, toString)
abstract ImmutableMap<K, V>(Map<K, V>) from Map<K, V> {
  	@:arrayAccess @:extern inline public function arrayAccess(key:K):V return this.get(key);

    public function set(key : K, value : V) : ImmutableMap<K, V> {
        var newMap = [for(k in this.keys()) 
            k => this.get(k)
        ];
        newMap.set(key, value);
        return newMap;
    }

    public function remove(key : K) : ImmutableMap<K, V> {
        return [for(k in this.keys()) 
            if(key != k) k => this.get(k)
        ];
    }
}
*/

typedef Action = {
    final name : String;
    final updates : ImmutableArray<{
        final path : String;
        final value : Dynamic;
    }>;
}

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

    public function update(action : Action) : T {
        // TODO: Handle Dataclass (instad of state.copy)
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
