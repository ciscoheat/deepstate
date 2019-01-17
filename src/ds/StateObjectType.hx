package ds;

/**
 * Used for describing the state tree and its types.
 */
enum StateObjectType {
    Bool;
    String;
    Int;
    Int32;
    Int64;
    Float;
    Date;
    Enumm;
    ImmutableList;
    ImmutableJson;
    Recursive(type : String);
    Anonymous(fields: Map<String, StateObjectType>);
    Instance(cls: String, fields: Map<String, StateObjectType>);
    Array(type: StateObjectType); // Always an ImmutableArray
    Map(type: StateObjectType); // Always an ImmutableMap
}
