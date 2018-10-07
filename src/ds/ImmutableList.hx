package ds;

@:forward(length, filter, first, isEmpty, iterator, join, last, map, toString)
abstract ImmutableList<T>(List<T>) from List<T> to Iterable<T> {
    public function add(item : T) : ImmutableList<T> {
        var newList = this.filter(i -> true);
        newList.add(item);
        return newList;
    }

    public function clear() : ImmutableList<T> {
        return new List<T>();
    }

    public function pop() : ImmutableList<T> {
        var newList = this.filter(i -> true);
        newList.pop();
        return newList;
    }

    public function push(item : T) : ImmutableList<T> {
        var newList = this.filter(i -> true);
        newList.push(item);
        return newList;
    }

    public function remove(v : T) : ImmutableList<T> {
        var newList = this.filter(i -> true);
        return newList.remove(v) ? newList : this;
    }
}
