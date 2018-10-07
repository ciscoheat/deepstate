package ds;

import haxe.ds.Map;

@:forward(exists, get, iterator, keys, toString)
abstract ImmutableMap<K, V>(Map<K, V>) from Map<K, V> {
  	@:arrayAccess @:extern inline function arrayAccess(key:K):V return this.get(key);

    public inline function new(map : Map<K, V>) this = map;

    /*
    public function set(key : K, value : V) : ImmutableMap<K, V> {
        var newMap : Map<K,V> = new Map(); 
        for(k in this.keys()) newMap.set(k, this[k]);
        newMap.set(key, value);
        return newMap;
    }

    public function remove(key : K) : ImmutableMap<K, V> {
        return [for(k in this.keys()) 
            if(key != k) k => this.get(k)
        ];
    }
    */
}
