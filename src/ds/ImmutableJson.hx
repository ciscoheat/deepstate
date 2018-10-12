package ds;

import haxe.DynamicAccess;

@:forward(copy, exists, keys)
abstract ImmutableJson(DynamicAccess<Dynamic>) {
    @:from public static function fromJson(json : Dynamic) {
        var dyn : DynamicAccess<Dynamic> = json;
        return new ImmutableJson(dyn.copy());
    }

    inline function new(o : DynamicAccess<Dynamic>)
        this = o;

    public function get(key : String) : Any
        return this[key];

    @:arrayAccess public function getJson(key : String) : ImmutableJson 
        return this[key];

    public function remove(key : String) : ImmutableJson {
        var copy = this.copy();
        return copy.remove(key) ? copy : new ImmutableJson(this);
    }

    public function set(key : String, value : Any) : ImmutableJson {
        var copy = this.copy();
        copy.set(key, value);
        return copy;
    }
}
