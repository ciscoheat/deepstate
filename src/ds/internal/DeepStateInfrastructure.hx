package ds.internal;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.DynamicAccess;
import ds.ImmutableArray;
import DeepState.MetaObjectType;

using Lambda;
using haxe.macro.TypeTools;
using haxe.macro.MacroStringTools;
using haxe.macro.ExprTools;

/**
 * A macro build class for checking that the state type is final,
 * and creating a path => type statec structure for quick access.
 */
class DeepStateInfrastructure {
    static public function build() {

        function stateFieldType(type : Type, count = 0) : MetaObjectType {
            if(count > 2)
                Context.error("Recursive type follow for " + type, Context.currentPos());

            return switch type {
                case TEnum(t, params):
                    Enum;

                case TAnonymous(a):
                    var fields = new Map<String, MetaObjectType>();
                    for(field in a.get().fields) switch field.kind {
                        case FVar(read, write) if(write == AccNever || write == AccCtor):
                            fields.set(field.name, stateFieldType(field.type));
                        case _:
                            Context.error('Field is not final, cannot be used in DeepState.', field.pos);
                    }
                    Anonymous(fields);

                case TInst(t, _):
                    var type = t.get();
                    if(type.pack.length == 0 && type.name == "String") Basic
                    else if(type.pack.length == 0 && type.name == "Date") Basic
                    else if(type.pack.length == 0 && type.name == "Array")
                        Context.error('Field is a mutable Array, cannot be used in DeepState. Use ds.ImmutableArray instead.', Context.currentPos());
                    else {
                        var fields = new Map<String, MetaObjectType>();
                        for(field in type.fields.get()) switch field.kind {
                            case FVar(read, write):
                                if(field.isFinal)
                                    fields.set(field.name, stateFieldType(field.type));
                                else
                                    Context.error('Field is not final, cannot be used in DeepState.', field.pos);
                            case FMethod(_):
                        }

                        var clsName = haxe.macro.MacroStringTools.toDotPath(type.pack, type.name);
                        Instance(clsName, fields);
                    }
                
                case TAbstract(t, params):
                    var abstractType = t.get();

                    if(abstractType.pack.length == 0 && ( 
                        abstractType.name == "Bool" || 
                        abstractType.name == "Float" ||
                        abstractType.name == "Int"
                    )) { 
                        Basic;
                    }
                    else if(abstractType.pack[0] == "haxe" && abstractType.name == "Int64") 
                        Basic
                    else if(abstractType.pack[0] == "ds" && abstractType.name == "ImmutableJson")
                        Basic
                    else if(abstractType.pack[0] == "ds" && (
                        abstractType.name == "ImmutableList" ||
                        abstractType.name == "ImmutableMap"
                    )) {
                        Basic;
                    }
                    else if(abstractType.pack[0] == "ds" && abstractType.name == "ImmutableArray") {
                        Array(stateFieldType(params[0]));
                    }
                    else {
                        stateFieldType(Context.followWithAbstracts(abstractType.type), count+1);
                    }

                case TType(t, params):
                    var typede = t.get();
                    stateFieldType(typede.type, count+1);

                case TLazy(f):
                    stateFieldType(f(), count+1);

                case x:
                    Context.error('Unsupported DeepState type: $x', Context.currentPos());
            }
        }

        /////////////////////////////////////////////////////////////

        var cls = Context.getLocalClass().get();
        var stateType = stateFieldType(cls.superClass.params[1]);

        function toExpr(t : MetaObjectType) : Expr {
            function mapToExpr(map : Map<String, MetaObjectType>) : Expr {
                return {
                    expr: EArrayDecl([for(key in map.keys()) {
                        expr: EBinop(OpArrow, macro $v{key}, toExpr(map[key])),
                        pos: Context.currentPos()
                    }]),
                    pos: Context.currentPos()
                }
            }

            return switch t {
                case Basic: macro DeepState.MetaObjectType.Basic;
                case Enum: macro DeepState.MetaObjectType.Enum;
                case Anonymous(fields): macro DeepState.MetaObjectType.Anonymous(${mapToExpr(fields)});
                case Instance(cls, fields): macro DeepState.MetaObjectType.Instance($v{cls}, ${mapToExpr(fields)});
                case Array(type): macro DeepState.MetaObjectType.Array(${toExpr(type)});
            }
        }

        /*
        trace(toExpr(stateType).toString());

        //trace("===== " + cls.name + " =====");
        //trace(Std.string(stateType).split("(").join("(\n").split(")").join(")\n"));

        var e = macro state.board[i+1][5].piece.name[last];

        var output : Array<String> = [];
        function debugExpr(e : Expr) switch e.expr {
            case EField(e1, name): 
                output.push("Field: " + name);
                debugExpr(e1);
            case EArray(e1, e2):
                output.push("Array: " + e2.toString());
                debugExpr(e1);
            case EConst(CIdent(s)):
                output.push("Field: " + s);
            case x:
                output.push("UNKNOWN: " + x);
        }
        debugExpr(e);
        output.reverse();
        trace("\n" + output.join("\n")+ "\n================================");
        */

        // Add a constructor if not defined
        var fields = Context.getBuildFields();
        if(!fields.exists(f -> f.name == "new")) {
            fields.push({
                access: [APublic],
                kind: FFun({
                    args: [
                        {name: 'currentState', type: null},
                        {name: 'middlewares', type: null, opt: true}
                    ],
                    expr: macro super(currentState, stateType, middlewares),
                    ret: null
                }),
                name: "new",
                pos: Context.currentPos()
            });
        }
        else if(!fields.exists(f -> f.name == "copy")) {
            Context.warning(
                "'copy' method not overridden despite inherited constructor.", 
                fields.find(f -> f.name == "new").pos
            );
        }

        // Add the stateType map
        fields.push({
            access: [AFinal, AStatic],
            doc: "Internal variable for accessing the state.",
            kind: FieldType.FVar(null, toExpr(stateType)),
            name: "stateType",
            pos: Context.currentPos()
        });

        return fields;
    }
}
#end