@:forward(exists, get, iterator, keys, toString)
abstract ImmutableMap<K, V>(Map<K, V>) from Map<K, V> {
  	@:arrayAccess @:extern inline public function arrayAccess(key:K):V return this.get(key);

    /*
    public function set(key : K, value : V) : ImmutableMap<K, V> {
        var newMap : Map<K,V> = [for(k in this.keys()) 
            k => this.get(k)
        ];
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
