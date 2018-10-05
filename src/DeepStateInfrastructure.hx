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
                for(f in a.get().fields) switch f.kind {
                    case FVar(read, write) if(write == AccNever || write == AccCtor):
                        testFinalType(name + "." + f.name, f.type);
                    case _:
                        Context.error(name + "." + f.name + " is not final, type cannot be used in DeepState.", f.pos);
                }
            case TInst(t, _):
                var type = t.get();
                if(type.name == "String" && type.pack.length == 0) return;
                else {
                    for(field in type.fields.get()) switch field.kind {
                        case FVar(read, write):
                            var fieldName = name + "." + field.name;
                            if(write == AccNever || write == AccCtor) testFinalType(fieldName, field.type);
                            else Context.error('Field "$fieldName" is not final, cannot be used in DeepState.', type.pos);
                        case FMethod(_): return;
                    }                    
                }
            
            case TAbstract(t, _):
                var abstractType = t.get();
                if(abstractType.pack.length == 0 && 
                    (abstractType.name == "Int" || abstractType.name == "Bool" || abstractType.name == "Float")
                ) return
                else testFinalType(name + "." + abstractType.name, Context.followWithAbstracts(abstractType.type));

            case x:
                Context.error("Unsupported final type check: " + x, Context.currentPos());
        }

        function buildStateType(type : Type) switch type {
            case TInst(t, params): 
                //Context.warning("Building DeepState from instance " + t + " with params " + params, t.get().pos);
                testFinalType(t.get().name, type);

                /*
                case TType(t2, _): 
                    testFinalType("", t2.get().type);
                    return null;
                    //return Context.error("Type is not final, cannot use in DeepState", Context.currentPos());

                case x:
                    return Context.error("Unsupported type: " + x, Context.currentPos());
                */

            case TType(t, _):
                //trace(t); 
                //if(params.length > 0) Context.error("Typedefs with parameters are not supported.", t.get().pos);
                var realType : DefType = t.get();
                var storeType = realType.type;
                //var complexType = Context.toComplexType(storeType);
                testFinalType(realType.name, storeType);

            case t:
                trace(t);
                Context.error("Class expected", Context.currentPos());
        }

        var cls = Context.getLocalClass().get();
        if(cls.superClass == null) Context.error("Class must extend DeepState<T>, where T is the state type.", cls.pos);

        buildStateType(cls.superClass.params[0]);
        return null;
    }
}
#end