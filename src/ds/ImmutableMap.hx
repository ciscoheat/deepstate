package ds;

import haxe.ds.Map;

@:multiType @:forward(exists, get, iterator, keys, toString)
abstract ImmutableMap<K, V>(Map<K, V>) from Map<K, V> {
  	@:arrayAccess @:extern inline function arrayAccess(key:K):V return this.get(key);

    public function new(map : Map<K, V>); // this = map;

    public function set(key : K, value : V) : ImmutableMap<K, V> {
        var newMap : Map<K,V> = this.copy();
        newMap.set(key, value);
        return newMap;
    }

    public function remove(key : K) : ImmutableMap<K, V> {
        var newMap : Map<K,V> = this.copy();
        newMap.remove(key);
        return newMap;
    }
}
