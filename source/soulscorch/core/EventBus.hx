package soulscorch.core;

/**
 * Decoupled global event dispatcher. Systems subscribe to named events and
 * publish data without holding direct references to each other.
 */
typedef EventHandler = Dynamic->Void;

class EventBus {
    public static var instance(default, null):EventBus;

    var handlers:Map<String, Array<EventHandler>> = new Map();

    public function new() {
        instance = this;
    }

    public function on(event:String, handler:EventHandler):Void {
        if (!handlers.exists(event)) handlers.set(event, []);
        handlers.get(event).push(handler);
    }

    public function off(event:String, handler:EventHandler):Void {
        if (!handlers.exists(event)) return;
        handlers.set(event, handlers.get(event).filter(function(h) return h != handler));
    }

    public function once(event:String, handler:EventHandler):Void {
        var wrapper:EventHandler = null;
        wrapper = function(data:Dynamic) {
            off(event, wrapper);
            handler(data);
        };
        on(event, wrapper);
    }

    public function emit(event:String, ?data:Dynamic):Void {
        if (!handlers.exists(event)) return;
        for (h in handlers.get(event)) {
            h(data);
        }
    }

    public function clear(event:String):Void {
        if (handlers.exists(event)) handlers.remove(event);
    }

    public function clearAll():Void {
        handlers = new Map();
    }

    public static function subscribe(event:String, handler:EventHandler):Void {
        if (instance != null) instance.on(event, handler);
    }

    public static function publish(event:String, ?data:Dynamic):Void {
        if (instance != null) instance.emit(event, data);
    }
}
