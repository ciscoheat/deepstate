import haxe.Unserializer;
import haxe.DynamicAccess;
import haxe.macro.Context;
import haxe.macro.Expr;
import ds.*;

using Lambda;

#if macro
using haxe.macro.Tools;
using haxe.macro.TypeTools;

// Intermediary enum, used to test for duplicate actions before
// transforming it to to Action.
private enum PathAccessExpr {
    Field(name : String);
    Array(e : Expr);
    Map(e : Expr);
}

private typedef ActionUpdateExpr = {
    var path : Array<PathAccessExpr>;
    var value : Expr;
}
#end

/////////////////////////////////////////////////////////////////////

#if !macro
@:genericBuild(ds.internal.DeepStateInfrastructure.genericBuild())
#end
class DeepState<T> {
    #if macro

    // Test if types unify by trying to assign a temp var with the new value
    static function unifies(type : ComplexType, value : Expr) return try {
        Context.typeof(macro var _DStest : $type = $value);
        true;
    } catch(e : Dynamic) false;

    // Used when testing if array access is for Array or Map
    static var intType = TPath({name: "Int", pack: []});

    static function _updateField(path : Expr, pathType : haxe.macro.Type, newValue : Expr) : ActionUpdateExpr {
        return if(!unifies(Context.toComplexType(pathType), newValue)) {
            Context.error("Value should be of type " + pathType.toString(), newValue.pos);
        } else {
            // Detects the initial "asset.state" reference.
            var filterPath = true;
            var paths = new Array<PathAccessExpr>();

            function parseUpdateExpr(e : Expr) switch e.expr {
                case EField(e1, name): 
                    if(name == "state") filterPath = false
                    else if(filterPath) paths.push(Field(name));
                    parseUpdateExpr(e1);

                case EArray(e1, e2):
                    paths.push(unifies(intType, e2)
                        ? Array(e2)
                        : Map(e2)
                    );
                    parseUpdateExpr(e1);

                case EConst(CIdent(name)):
                    if(name == "state") filterPath = false 
                    else if(filterPath) paths.push(Field(name));

                case x:
                    Context.error("Invalid DeepState update expression.", e.pos);
            }
            parseUpdateExpr(path);
            paths.reverse();

            { 
                path: paths,
                value: newValue
            }
        }
    }

    /////////////////////////////////////////////////////////////////

    static function _updateFunc(path : Expr, pathType : haxe.macro.Type, newValue : Expr) {
        return switch newValue.expr {
            case EFunction(name, f) if(f.args.length == 1):
                f.ret = f.args[0].type = Context.toComplexType(pathType);
                var funcCall = {
                    expr: ECall(newValue, [path]),
                    pos: newValue.pos
                }
                _updateField(path, pathType, funcCall);
            case x:
                Context.error('Function must take an argument of type $pathType and return the same.', newValue.pos);
        }
    }

    static function _updatePartial(path : Expr, pathType : haxe.macro.Type, fields : Array<ObjectField>) {
        return [for(f in fields) {
            var fieldName = f.field;
            var fieldPath = macro $path.$fieldName;

            var fieldType = try Context.typeof(fieldPath)
            catch(e : Dynamic) {
                Context.error("Cannot determine field type, try providing a type hint.", f.expr.pos);
            }

            _updateField(fieldPath, fieldType, f.expr);
        }];
    }

    static function _updateIn(path : Expr, newValue : Expr) {
        var pathType = try Context.typeof(path)
        catch(e : Dynamic) {
            Context.error("Cannot find field or its type in state.", path.pos);
        }

        return switch newValue.expr {
            case EObjectDecl(fields) if(!unifies(Context.toComplexType(pathType), newValue)): 
                // Update with a partial object
                _updatePartial(path, pathType, fields);

            case EFunction(name, f):
                // Update with a function/lambda expression 
                [_updateFunc(path, pathType, newValue)];
            
            case _: 
                // Update any other value
                [_updateField(path, pathType, newValue)];
        }
    }

    /////////////////////////////////////////////////////////////////

    static var typeNameCalls = new Map<String, {hash: String, pos: haxe.macro.Position}>();
    static function checkDuplicateAction(asset : Expr, actionType : String, updates : Array<ActionUpdateExpr>, pos) {

        var clsName = try switch Context.typeof(asset) {
            case TInst(t, _):
                var cls = t.get();
                cls.module + "." + cls.pack.join(".") + "." + cls.name + ".";
            case _:
                Context.error("Asset is not a class.", asset.pos);
        } catch(e : Dynamic) {
            Context.error("Asset type not found, please provide a type hint.", asset.pos);
        }

        var updateHash = [for(u in updates) {
            var str = [for(p in u.path) switch p {
                case Field(name): '.$name';
                case Array(_): "[]";
                case Map(_): "[]";
            }].join("");
            while(str.indexOf(".") == 0) str = str.substr(1);
            str;
        }];
        updateHash.sort((a,b) -> a < b ? -1 : 1);

        //trace(updateHash);

        var hashKey = clsName + actionType;
        var actionHash = ' => (' + updateHash.join(") (") + ')';

        if(typeNameCalls.exists(hashKey)) {
            var typeHash = typeNameCalls.get(hashKey);

            if(typeHash.hash != actionHash) {
                var msg = 'Duplicate action type "$actionType", change updates or action type name.';
                Context.warning(msg, typeHash.pos);
                Context.error(msg, pos);
            }
        }
        else {
            #if deepstate_list_actions
            Context.warning('$actionType$actionHash', pos);
            #end
            typeNameCalls.set(hashKey, {hash: actionHash, pos: pos});
        }
    }

    public static function _update(asset : Expr, args : Array<Expr>) {
        var actionType : Expr = null;

        // Extract Action updates from the arguments
        var updates = args.mapi((i, arg) -> switch arg.expr {
            case EBinop(OpAssign, e1, e2):
                _updateIn(e1, e2);

            case _: 
                if(i == args.length-1 && args.length > 1)
                    actionType = arg;
                else
                    Context.error("Arguments must be an assignment, or a String if last argument.", arg.pos);
                null;
                
        }).filter(u -> u != null).flatMap(u -> u).array();

        // Set a default action type (Class.method) if not specified
        var aTypeString : String;
        var aTypePos : Position;

        function defaultType(pos) {
            aTypeString = Context.getLocalClass().get().name + "." + Context.getLocalMethod();
            aTypePos = pos;
            return macro $v{aTypeString};
        }

        var aType = if(actionType == null) defaultType(Context.currentPos()) else switch actionType.expr {
            case EConst(CIdent("null")):
                defaultType(actionType.pos);
            case EConst(CString(s)):
                aTypeString = s;
                aTypePos = actionType.pos;
                actionType;
            case _:
                actionType;
        }

        checkDuplicateAction(asset, aTypeString, updates, aTypePos);

        // Display mode and vshaxe diagnostics have some problems with this.
        //if(Context.defined("display") || Context.defined("display-details")) 
            //return macro null;

        var realUpdates = [for(u in updates) {
            var paths = [for(p in u.path) switch p {
                case Field(name): macro ds.PathAccess.Field($v{name});
                case Array(e): macro ds.PathAccess.Array($e);
                case Map(e): macro ds.PathAccess.Map($e);
            }];

            macro {
                path: $a{paths},
                value: ${u.value}
            }
        }];

        return macro $asset.updateState({
            type: $aType,
            updates: $a{realUpdates}
        });
    }

    #end
}
