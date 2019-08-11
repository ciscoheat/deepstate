package ds;
import haxe.Constraints;

@:multiType
@:forward(exists, get, iterator, keys, toString)
abstract ImmutableMap<K, V>(IMap<K, V>) from haxe.IMap<K, V> {
  	@:arrayAccess @:extern public inline function arrayAccess(key : K) : V 
      return this.get(key);

    public function new(map : Map<K, V>); // this = map;

    public function copy() : ImmutableMap<K, V> {
        return this.copy();
    }

    public function set(key : K, value : V) : ImmutableMap<K, V> {
        var newMap : IMap<K,V> = this.copy();
        newMap.set(key, value);
        return newMap;
    }

    public function remove(key : K) : ImmutableMap<K, V> {
        var newMap : IMap<K,V> = this.copy();
        newMap.remove(key);
        return newMap;
    }
}
