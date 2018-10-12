package ds;

@:forward(length, filter, first, isEmpty, iterator, join, last, map, toString)
abstract ImmutableList<T>(List<T>) {
    inline function new(list : List<T>)
        this = list;

    @:from static public function fromList<T>(l : List<T>) : ImmutableList<T> {
        return new ImmutableList(Lambda.list(l));
    }

    @:from static public function fromArray<T>(a : Array<T>) : ImmutableList<T> {
        return fromList(Lambda.list(a.copy()));
    }

    public function add(item : T) : ImmutableList<T> {
        var newList = Lambda.list(this);
        newList.add(item);
        return newList;
    }

    public function clear() : ImmutableList<T> {
        return new List<T>();
    }

    public function pop() : ImmutableList<T> {
        var newList = Lambda.list(this);
        newList.pop();
        return newList;
    }

    public function push(item : T) : ImmutableList<T> {
        var newList = Lambda.list(this);
        newList.push(item);
        return newList;
    }

    public function remove(v : T) : ImmutableList<T> {
        var newList = Lambda.list(this);
        return newList.remove(v) ? newList : new ImmutableList(this);
    }
}
