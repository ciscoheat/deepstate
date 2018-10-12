package ds.internal;

#if macro

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using Lambda;

/**
 * A macro build class for checking that the state type is final.
 */
class DeepStateInfrastructure {
    static public function build() {
        function testTypeFields(name : String, type : Type) : Void {
            //trace('\\-- Testing type $name ($type) for final');
            switch type {
                case TAnonymous(a):
                    // Check if all fields in typedef are final
                    for(f in a.get().fields) {
                        var fieldName = name + "." + f.name;
                        //trace("   \\- Testing field " + fieldName);
                        switch f.kind {
                            case FVar(read, write) if(write == AccNever || write == AccCtor):
                                testTypeFields(fieldName, f.type);
                            case _:
                                Context.error('$fieldName is not final, type cannot be used in DeepState.', f.pos);
                        }
                    }
                case TInst(t, _):
                    var type = t.get();
                    if(type.name == "String" && type.pack.length == 0) { 
                        return;
                    } else {
                        // Check if all public fields in class are final
                        for(field in type.fields.get()) if(field.isPublic) switch field.kind {
                            case FVar(read, write):
                                var fieldName = name + "." + field.name;
                                if(write == AccNever || write == AccCtor) 
                                    testTypeFields(fieldName, field.type);
                                else 
                                    Context.error('$fieldName is not final, type cannot be used in DeepState.', type.pos);
                            case _:
                                return;
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
                    )) return
                    else if(abstractType.pack[0] == "ds" && 
                        abstractType.name == "ImmutableJson"
                    ) return
                    else if(abstractType.pack[0] == "ds" && (
                        abstractType.name == "ImmutableArray" || 
                        abstractType.name == "ImmutableList" ||
                        abstractType.name == "ImmutableMap"
                    )) {
                        // TODO: Include type params in name
                        testTypeFields(
                            name + "." + abstractType.name + "<T>", 
                            params[0]
                        );
                    }
                    else {
                        testTypeFields(
                            name + "." + abstractType.name, 
                            Context.followWithAbstracts(abstractType.type)
                        );
                    }

                case TType(t, params):
                    testTypeFields(name + "." + t.get().name, t.get().type);

                case x:
                    Context.error('Unsupported DeepState type for $name: $x', Context.currentPos());
            }
        }

        var cls = Context.getLocalClass().get();

        // Until @:genericBuild works properly, this is required
        if(cls.superClass == null || cls.superClass.params.length != 1)
            Context.error("Class must extend DeepState<T>, where T is the state type.", cls.pos);

        var type = cls.superClass.params[0];

        switch type {
            case TInst(t, params): 
                Context.error("Only anonymous structures are supported for DeepState at the moment.", Context.currentPos());
                /*
                //trace("=== Building DeepState from instance " + t + " with params " + params);
                testTypeFields(t.get().name, type);
                */

            case TType(t, params):
                var realType : DefType = t.get();
                //trace("=== Building DeepState from typedef " + t + " with params " + params);
                testTypeFields(realType.name, realType.type);

            case x:
                Context.error("Unsupported type for DeepState: " + x, Context.currentPos());
        }

        return null;
    }
}
#end