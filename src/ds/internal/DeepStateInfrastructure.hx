package ds.internal;

#if macro

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using Lambda;

class DeepStateInfrastructure {
    static public function build() {
        function testFinalType(name : String, type : Type) : Void switch type {
            case TAnonymous(a):
                // Check if all fields are final
                for(f in a.get().fields) /*if(f.isPublic)*/ switch f.kind {
                    case FVar(read, write) if(write == AccNever || write == AccCtor):
                        testFinalType(name + "." + f.name, f.type);
                    case _:
                        Context.error(name + "." + f.name + " is not final, type cannot be used in DeepState.", f.pos);
                }
            case TInst(t, _):
                var type = t.get();
                if(type.name == "String" && type.pack.length == 0) return;
                else {
                    for(field in type.fields.get()) if(field.isPublic) switch field.kind {
                        case FVar(read, write):
                            var fieldName = name + "." + field.name;
                            if(write == AccNever || write == AccCtor) testFinalType(fieldName, field.type);
                            else Context.error('$fieldName is not final, type cannot be used in DeepState.', type.pos);
                        case _:
                            return;
                    }
                }
            
            case TAbstract(t, _):
                // Allow immutable Int, Bool, Float
                var abstractType = t.get();
                if(abstractType.pack.length == 0 && ( 
                    abstractType.name == "Bool" || 
                    abstractType.name == "Float" ||
                    abstractType.name == "Int" || 
                    abstractType.name == "Int64"
                )) return
                else {
                    testFinalType(
                        name + "." + abstractType.name, 
                        Context.followWithAbstracts(abstractType.type)
                    );
                }

            case x:
                Context.error('Unsupported type for $name: $x', Context.currentPos());
        }

        var cls = Context.getLocalClass().get();

        if(cls.superClass == null || cls.superClass.params.length != 1)
            Context.error("Class must extend DeepState<T>, where T is the state type.", cls.pos);

        var type = cls.superClass.params[0];

        switch type {
            case TInst(t, params): 
                Context.warning("Building DeepState from instance " + t + " with params " + params, t.get().pos);
                testFinalType(t.get().name, type);

            case TType(t, params):
                var realType : DefType = t.get();
                var storeType = realType.type;
                Context.warning("Building DeepState from typedef " + t + " with params " + params, realType.pos);
                testFinalType(realType.name, storeType);

            case x:
                Context.error("Unsupported type for DeepState: " + x, Context.currentPos());
        }

        return null;
    }
}
#end