package ds;

@:forward(length, concat, copy, filter, indexOf, iterator, join, lastIndexOf, map, slice, splice, toString)
abstract ImmutableArray<T>(Array<T>) to Iterable<T> {
	@:arrayAccess inline function arrayAccess(key : Int) : T 
        return this[key];

    inline function new(array : Array<T>)
        this = array;

    ///// From/to conversions /////

    @:from public static function fromArray<T2>(array : Array<T2>) 
        return new ImmutableArray(array.copy());

//    @:to public function toIterable() : Iterable<T>
//        return this;

    public function toArray() : Array<T>
        return this.copy();

    // TODO: This will probably cause object schizohprenia.
    /*
    @:to public function toAnon()
    	return {
            length: this.length, concat: this.concat, copy: copy, filter: this.filter, 
            indexOf: this.indexOf, iterator: this.iterator, join: this.join, 
            lastIndexOf: this.lastIndexOf, map: this.map, slice: this.slice, 
            splice: this.splice, toString: this.toString,
            insert: insert, pop: pop, push: push, remove: remove, reverse: reverse,
            shift: shift, sort: sort, unshift: unshift, first: first, last: last
        };
    */

    ///// Array API modifications /////

    //public function copy() this.copy();

    public function insert(pos : Int, x : T) : ImmutableArray<T> {
        var newArray = this.copy();
        newArray.insert(pos, x);
        return newArray;
    }

    public function pop() : ImmutableArray<T> {
        var newArray = this.copy();
        newArray.pop();
        return newArray;
    }

    public function push(x : T) : ImmutableArray<T> {
        var newArray = this.copy();
        newArray.push(x);
        return newArray;
    }

    public function remove(x : T) : ImmutableArray<T> {
        var newArray = this.copy();
        return newArray.remove(x) ? newArray : new ImmutableArray(this);
    }

    public function reverse() : ImmutableArray<T> {
        var newArray = this.copy();
        newArray.reverse();
        return newArray;
    }

    public function shift() : ImmutableArray<T> {
        var newArray = this.copy();
        newArray.shift();
        return newArray;
    }

    public function sort(f : T -> T -> Int) : ImmutableArray<T> {
        var newArray = this.copy();
        newArray.sort(f);
        return newArray;
    }

    public function unshift(x : T) : ImmutableArray<T> {
        var newArray = this.copy();
        newArray.unshift(x);
        return newArray;
    }

    ///// Additions from standard Array interface /////

    public function first() : haxe.ds.Option<T> 
        return this.length == 0 ? None : Some(this[0]);

    public function last() : haxe.ds.Option<T>
        return this.length == 0 ? None : Some(this[this.length-1]);
}
