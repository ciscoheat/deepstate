package ds.internal;

#if macro

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import ds.ImmutableArray;
import haxe.DynamicAccess;

using Lambda;
using haxe.macro.TypeTools;
using haxe.macro.MacroStringTools;

/**
 * A macro build class for checking that the state type is final,
 * and storing path => type data for quick access to type checking.
 */
class DeepStateInfrastructure {
    static final checkedTypes = new Map<String, Bool>();

    static public function build() {       
        // { "state.field": {cls: clsName, fields: [f1,f2,f3,...]} }
        var objectFields = new haxe.DynamicAccess<{cls: String, fields: Array<String>}>();

        function setCheckedType(t : {pack : Array<String>, module: String, name: String}) {
            var typeName = t.pack.join(".") + "." + t.module + "." + t.name;
            checkedTypes.set(typeName, true);
        }

        function typeIsChecked(t : {pack : Array<String>, module: String, name: String}) {
            return checkedTypes.exists(t.pack.join(".") + "." + t.module + "." + t.name);
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
                    if(type.pack.length == 0 && type.name == "String") {}
                    else if(type.pack.length == 0 && type.name == "Date") {}
                    else if(!typeIsChecked(type)) {
                        setCheckedType(type);
                        var fields = new Array<String>();
                        // Check if all public fields in class are final
                        for(field in type.fields.get()) if(field.isPublic) switch field.kind {
                            case FVar(read, write):
                                var fieldName = name.push(field.name);
                                if(write == AccNever || write == AccCtor) {
                                    testTypeFields(fieldName, field.type);
                                    fields.push(field.name);
                                }
                                else {
                                    Context.error('${fieldName.join(".")} is not final, type cannot be used in DeepState.', type.pos);
                                }
                            case _:
                        }

                        // Add object information to metadata
                        var clsName = haxe.macro.MacroStringTools.toDotPath(type.pack, type.name);
                        objectFields.set(name.join(''), {cls: clsName, fields: fields});
                    }
                
                case TAbstract(t, params):
                    // Allow Int, Bool, Float and the ds.ImmutableX types 
                    var abstractType = t.get();
                    if(abstractType.pack.length == 0 && ( 
                        abstractType.name == "Bool" || 
                        abstractType.name == "Float" ||
                        abstractType.name == "Int"
                    )) {} // Ok
                    else if(abstractType.pack[0] == "haxe" && 
                        abstractType.name == "Int64"
                    ) {} // Ok
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
                    var typede = t.get();
                    if(!typeIsChecked(typede)) {
                        setCheckedType(typede);
                        testTypeFields(name, typede.type);
                    }

                case TLazy(f):
                    testTypeFields(name, f());

                case x:
                    Context.error('Unsupported DeepState type for ${name.join(".")}: $x', Context.currentPos());
            }
        }

        /////////////////////////////////////////////////////////////

        var cls = Context.getLocalClass().get();

        // Until @:genericBuild works properly, this is required
        if(cls.superClass == null || cls.superClass.params.length != 1)
            Context.error("Class must extend DeepState<T>, where T is the state type.", cls.pos);

        var type = cls.superClass.params[0];
        testTypeFields([], type);

        // Set metadata that DeepState will access in its constructor.
        cls.meta.add("stateObjects", [macro $v{objectFields}], cls.pos);

        return null;
    }
}
#end