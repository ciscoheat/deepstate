package ds;

class Subscription {
    public var closed(default, null) : Bool;
    final unsubscribeObserver : Void -> Void;

    public function new(unsubscribeObserver : Void -> Void) {
        this.unsubscribeObserver = unsubscribeObserver;
        this.closed = false;
    }

    public function unsubscribe() : Void {
        if(closed) return;
        closed = true;
        unsubscribeObserver();
    }
}