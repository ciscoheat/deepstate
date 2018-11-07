package ds.internal;

#if macro

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import ds.ImmutableArray;
import haxe.DynamicAccess;
import ds.internal.StateNode;

using Lambda;
using haxe.macro.TypeTools;
using haxe.macro.MacroStringTools;

/**
 * A macro build class for checking that the state type is final,
 * and storing path => type data for quick access to type checking.
 */
class DeepStateInfrastructure {
    /*
    static public var pathMap(default, null) : Map<String, Map<String, ComplexType>> 
        = new Map<String, Map<String, ComplexType>>();
    */

    static public function build() {
        //var stateType : DefType;
        //var pathToType = new Map<String, ComplexType>();
        //var pathAccess = new Map<String, Expr>();
        //var defaultState = new DynamicAccess<Dynamic>();

        function stateNodeTree(name : String, type : Type) : StateNode {
            //if(name.last().equals(Some("state")))
                //Context.error("A field cannot be named 'state' in a state structure.", Context.currentPos());

            //trace('\\-- Testing type $type for final');
            return switch type {
                case TAnonymous(a):
                    // Check if all fields in typedef are final
                    var fields = [for(f in a.get().fields) {
                        //trace("   \\- Testing field " + fieldName.join("."));
                        switch f.kind {
                            case FVar(read, write) if(write == AccNever || write == AccCtor):
                                stateNodeTree(f.name, f.type);
                            case _:
                                Context.error('${f.name} is not final, type cannot be used in DeepState.', f.pos);
                        }
                    }];
                    Typedef(name, fields);

                case TInst(t, _):
                    var type = t.get();
                    trace("--------" + type.module + " - " + type.name);
                    if(type.name == "String" && type.pack.length == 0)
                        Var(name, "");
                    else if(type.name == "Date" && type.pack.length == 0)
                        Var(name, new Date(1970,0,1,1,0,0));
                    else {
                        // Check if all public fields in class are final
                        var fields = [];
                        for(field in type.fields.get()) if(field.isPublic) switch field.kind {
                            case FVar(read, write):
                                if(write == AccNever || write == AccCtor) 
                                    fields.push(stateNodeTree(field.name, field.type));
                                else
                                    Context.error('${field.name} is not final, type cannot be used in DeepState.', type.pos);
                            case _:
                        };
                        Object(name, {name: type.name, pack: type.pack}, fields);
                    }
                
                case TAbstract(t, params):
                    // Allow Int, Int64, Bool, Float and the ds.ImmutableX types 
                    var abstractType = t.get();
                    if(abstractType.pack.length == 0) switch abstractType.name {
                        case "Bool": Var(name, false);
                        case "Float": Var(name, 0.0);
                        case "Int": Var(name, 0);
                        case "Int64": Var(name, 0);
                        case _: 
                            stateNodeTree(name, Context.followWithAbstracts(abstractType.type));
                    }
                    else if(abstractType.pack[0] == "ds" && abstractType.name == "ImmutableJson") {
                        Var(name, new haxe.DynamicAccess<Dynamic>());
                    }
                    else if(abstractType.pack[0] == "ds") switch abstractType.name {
                        case "ImmutableArray": 
                            stateNodeTree(name, params[0]);
                            Array(name);
                        case "ImmutableList": 
                            stateNodeTree(name, params[0]);
                            List(name);
                        case _:
                            stateNodeTree(name, params[0]);
                    }
                    else {
                        stateNodeTree(name, Context.followWithAbstracts(abstractType.type));
                    }

                case TType(t, params):
                    stateNodeTree(name, t.get().type);

                case x:
                    Context.error('Unsupported DeepState type for $name: $x', Context.currentPos());
            }

            //var nameStr = name.join(".");
            //pathToType.set(nameStr, Context.toComplexType(type));
            //pathAccess.set(nameStr, macro () -> cast $p{name.unshift('state').toArray()});
        }

        function testTypeFields(name : ImmutableArray<String>, type : Type) : Void {
            if(name.last().equals(Some("state")))
                Context.error("A field cannot be named 'state' in a state structure.", Context.currentPos());

            //trace('\\-- Testing type ${name.join(".")} ($type) for final');
            switch type {
                case TAnonymous(a):
                    // Check if all fields in typedef are final
                    for(f in a.get().fields) {
                        var fieldName = name.push(f.name);
                        //trace("   \\- Testing field " + fieldName.join("."));
                        switch f.kind {
                            case FVar(read, write) if(write == AccNever || write == AccCtor):
                                testTypeFields(fieldName, f.type);
                            case _:
                                Context.error('${fieldName.join(".")} is not final, type cannot be used in DeepState.', f.pos);
                        }
                    }
                case TInst(t, _):
                    var type = t.get();
                    if(type.name != "String" || type.pack.length != 0) {
                        // Check if all public fields in class are final
                        for(field in type.fields.get()) if(field.isPublic) switch field.kind {
                            case FVar(read, write):
                                var fieldName = name.push(field.name);
                                if(write == AccNever || write == AccCtor) 
                                    testTypeFields(fieldName, field.type);
                                else {
                                    Context.error('${fieldName.join(".")} is not final, type cannot be used in DeepState.', type.pos);
                                }
                            case _:
                        }
                    }
                
                case TAbstract(t, params):
                    // Allow Int, Int64, Bool, Float and the ds.ImmutableX types 
                    var abstractType = t.get();
                    if(abstractType.pack.length == 0 && ( 
                        abstractType.name == "Bool" || 
                        abstractType.name == "Float" ||
                        abstractType.name == "Int" || 
                        abstractType.name == "Int64"
                    )) {} // Ok
                    else if(abstractType.pack[0] == "ds" && 
                        abstractType.name == "ImmutableJson"
                    ) {} // Ok
                    else if(abstractType.pack[0] == "ds" && (
                        abstractType.name == "ImmutableArray" || 
                        abstractType.name == "ImmutableList" ||
                        abstractType.name == "ImmutableMap"
                    )) {
                        testTypeFields(name, params[0]);
                    }
                    else {
                        testTypeFields(
                            name, 
                            Context.followWithAbstracts(abstractType.type)
                        );
                    }

                case TType(t, params):
                    testTypeFields(name, t.get().type);

                case x:
                    Context.error('Unsupported DeepState type for ${name.join(".")}: $x', Context.currentPos());
            }

            //var nameStr = name.join(".");
            //pathToType.set(nameStr, Context.toComplexType(type));
            //pathAccess.set(nameStr, macro () -> cast $p{name.unshift('state').toArray()});
        }

        /////////////////////////////////////////////////////////////

        var cls = Context.getLocalClass().get();
        trace("=== " + cls.name);

        // Until @:genericBuild works properly, this is required
        if(cls.superClass == null || cls.superClass.params.length != 1)
            Context.error("Class must extend DeepState<T>, where T is the state type.", cls.pos);

        var type = cls.superClass.params[0];
        var tree = stateNodeTree("", type);

        function printTree(node : StateNode, level = 0) {
            var i = 0;
            var tab = ""; while(i++ < level) tab += "  ";
            switch node {
                case Typedef(name, fields):
                    trace(tab + '$name:');
                    for(f in fields) printTree(f, level+1);
                
                case Object(name, typePath, fields):
                    trace(tab + '$name ($typePath):');
                    for(f in fields) printTree(f, level+1);

                case Array(name):
                    trace(tab + 'Array: $name');

                case List(name):
                    trace(tab + 'List: $name');

                case Var(name, defaultValue):
                    trace(tab + '$name ($defaultValue)');
            }
        }
        //printTree(tree);

        return null;

        //pathMap.set(cls.pack.toDotPath(cls.name), pathToType);

        /*
        var fields = Context.getBuildFields();
        fields.push({
            access: [APrivate, AFinal],
            doc: "Internal DeepState field for path access.",
            kind: FVar(macro : Map<String, Void -> Any>, macro new Map<String, Void -> Any>()),
            name: "_dsPathAccess",
            meta: [{name: ":noCompletion", pos: Context.currentPos()}],
            pos: Context.currentPos()
        });

        switch fields.find(f -> f.name == "new").kind {
            case FFun(f):
                var values = [for(key in pathAccess.keys()) {
                    expr: EBinop(OpArrow, macro $v{key}, pathAccess[key]),
                    pos: pathAccess[key].pos
                }];

                var arrayExpr = {expr: EArrayDecl(values), pos: Context.currentPos()};

                f.expr = switch f.expr.expr {
                    case EBlock(exprs):
                        exprs.push(arrayExpr);
                        f.expr;
                    case x:
                        {
                            expr: EBlock([{
                                expr: f.expr.expr,
                                pos: f.expr.pos
                            }, arrayExpr]),
                            pos: f.expr.pos
                        }
                }
            case _:
                Context.error("Invalid constructor.", fields.find(f -> f.name == "new").pos);
        };

        return fields;
        */
    }
}
#end