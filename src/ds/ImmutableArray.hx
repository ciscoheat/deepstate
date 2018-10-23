package ds;

@:forward(length, concat, copy, filter, iterator, indexOf, join, lastIndexOf, map, slice, splice, toString)
abstract ImmutableArray<T>(Array<T>) {
	@:arrayAccess inline function arrayAccess(key : Int) : T 
        return this[key];

    inline function new(array : Array<T>)
        this = array;

    ///// From/to conversions /////

    @:from public static function fromArray<T2>(array : Array<T2>) 
        return new ImmutableArray(array.copy());

    @:to public function toIterable() : Iterable<T>
        return this;

    ///// Array API modifications /////

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

    public function resize(len : Int) : ImmutableArray<T> {
        var newArray = this.copy();
        newArray.resize(len);
        return newArray;
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

    ///// Lambda extension duplicate /////

    @:to public function array()
        return Lambda.array(this);
        
    public function concat(b : Iterable<T>)
    	return new ImmutableArray(Lambda.array(Lambda.concat(this, b)));

    public function count(?f : T -> Bool)
        return Lambda.count(this, f);

    public function empty()
        return Lambda.empty(this);

    public function exists(f:T -> Bool)
        return Lambda.exists(this, f);

    public function filter(f:T -> Bool)
        return new ImmutableArray(Lambda.array(Lambda.filter(this, f)));

    public function find(f:T -> Bool)
        return Lambda.find(this, f);

    public function flatMap<B>(f:T -> Iterable<B>)
        return new ImmutableArray(Lambda.array(Lambda.flatMap(this, f)));

    public function fold<T2>(f:T -> T2 -> T2, first:T2)
        return Lambda.fold(this, f, first);

    public function foreach(f:T -> Bool)
        return Lambda.foreach(this, f);

    public function has(elt:T)
        return Lambda.has(this, elt);

    public function indexOf(v:T)
        return Lambda.indexOf(this, v);

    public function iter(f:T -> Void)
        return Lambda.iter(this, f);

    public function list()
        return Lambda.list(this);

    public function map<T2>(f:T -> T2)
        return new ImmutableArray(Lambda.array(Lambda.map(this, f)));

    public function mapi<T2>(f:Int -> T -> T2)
        return new ImmutableArray(Lambda.array(Lambda.mapi(this, f)));
         
}
