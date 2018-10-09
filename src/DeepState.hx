import haxe.DynamicAccess;
import haxe.macro.Context;
import haxe.macro.Expr;

import ds.ImmutableArray;

using haxe.macro.Tools;
using Reflect;

typedef Action = {
    final type : String;
    final updates : ImmutableArray<{
        final path : String;
        final value : Any;
    }>;
}

@:autoBuild(ds.internal.DeepStateInfrastructure.build())
class DeepState<T> {
    #if !macro
    public var state(default, null) : T;

    function new(initialState : T) {
        this.state = initialState;
    }

    public function update(action : Action) : T {
        // TODO: Handle Dataclass (create a copy method based on type)
        var newState = if(action.updates.length == 1 && action.updates[0].path == "") {
            // Special case, if updating the whole state
            cast action.updates[0].value;
        } else {
            var copy = Reflect.copy(state);
            for(a in action.updates) {
                if(a.path == "") copy = cast Reflect.copy(a.value);
                else mutateStateCopy(cast copy, a.path, a.value);
            }
            copy;
        }

        // TODO: Apply middleware

        return this.state = newState;
    }

    function mutateStateCopy(newState : DynamicAccess<Dynamic>, updatePath : DeepStateNode, newValue : Any) : Void {
        var nodeName = updatePath.name();
        if(!newState.exists(nodeName)) throw "Key not found in state: " + updatePath;

        //trace('Updating: $updatePath');
        if(!updatePath.hasNext()) {
            //trace('updating $nodeName and finishing.');
            newState.set(nodeName, newValue);
        } else {
            var copy = Reflect.copy(newState.get(nodeName));            
            newState.set(nodeName, copy);
            mutateStateCopy(copy, updatePath.next(), newValue);
        }
    }

    #end

    macro public function updateIn(store : ExprOf<DeepState<Dynamic>>, path : Expr, newValue : Expr) {

        function unifies(type : ComplexType, value : Expr) return try {
            // Test if types unify by trying to assign a temp var with the new value
            Context.typeof(macro var _DStest : $type = $value);
            true;
        } catch(e : Dynamic) false;

        function stripPathPrefix(pathStr : String) {
            // Strip "store.state" from path
            for(v in Context.getLocalTVars()) {
                var pathTest = '${v.name}.';
                if(pathStr.indexOf(pathTest) == 0) {
                    pathStr = pathStr.substr(pathTest.length);
                    break;
                }
            }

            // Strip "state."
            return if(pathStr.indexOf("state.") == 0)
                pathStr.substr(6);
            else if(pathStr == "state") {
                // If only "state" is left, return empty string to make a full update.
                "";
            } else
                pathStr;
        }

        var pathType = try Context.typeof(path)
        catch(e : Dynamic) {
            Context.error("Cannot find field or its type in state.", path.pos);
        }

        var updates = if(!unifies(Context.toComplexType(pathType), newValue)) {
            // Direct unification failed. If value is an anonymous object, test if
            // all fields unify with respective type.
            switch newValue.expr {
                case EObjectDecl(fields): [for(f in fields) {
                    var fieldName = f.field;
                    var fieldPath = macro $path.$fieldName;

                    var fieldType = try Context.typeof(fieldPath)
                    catch(e : Dynamic) {
                        Context.error("Cannot determine field type, try providing a type hint.", f.expr.pos);
                    }

                    if(!unifies(Context.toComplexType(fieldType), f.expr)) {
                        Context.error("Value should be of type " + fieldType.toString(), f.expr.pos);
                    }

                    var strippedPath = stripPathPrefix(fieldPath.toString());

                    // Add an update
                    macro {
                        path: $v{strippedPath},
                        value: ${f.expr}
                    }
                }];
                case _:
                    Context.error("Value should be of type " + pathType.toString(), newValue.pos);
            }
        } else {
            [macro {
                path: $v{stripPathPrefix(path.toString())},
                value: $newValue
            }];
        }

        var actionName = Context.getLocalMethod();

        return macro $store.update({
            type: $v{actionName},
            updates: $a{updates}
        });
    }
}

private abstract DeepStateNode(ImmutableArray<String>) {
    public inline function new(a : ImmutableArray<String>) {
        if(a.length == 0) throw "DeepStateNode: Empty node list";
        this = a;
    }

    @:from
    public static function fromString(s : String) {
        return new DeepStateNode(new ImmutableArray(s.split(".")));
    }

    @:to
    public function toString() return this.join(".");

    public function hasNext() return this.length > 1;

    public function name() return this[0];

    public function next() : DeepStateNode {
        if(!hasNext()) throw "DeepStateNode: No more nodes."
        else return new DeepStateNode(new ImmutableArray(this.slice(1)));
    }

    public function isNextLeaf() {
        if(!hasNext()) throw "DeepStateNode: No more nodes."
        else return this.length == 2;
    }
}
