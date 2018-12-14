package ds.internal;

/**
 * Used for describing the state tree and its types.
 */
enum MetaObjectType {
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
    Anonymous(fields: Map<String, MetaObjectType>);
    Instance(cls: String, fields: Map<String, MetaObjectType>);
    Array(type: MetaObjectType); // Always an ImmutableArray
    Map(type: MetaObjectType); // Always an ImmutableMap
}
