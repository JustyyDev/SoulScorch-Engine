package soulscorch.backend.system;

typedef EventHandler = Dynamic->Void;

class EventBus {
    public static var instance(get, null):EventBus;
    private static var _instance:EventBus;

    private var handlers:Map<String, Array<EventHandler>> = new Map();

    public function new() {
        _instance = this;
    }

    public static inline function get_instance():EventBus {
        if (_instance == null) {
            _instance = new EventBus();
        }
        return _instance;
    }

    public function on(event:String, handler:EventHandler):Void {
        if (handler == null) return;
        if (!handlers.exists(event)) {
            handlers.set(event, []);
        }
        handlers.get(event).push(handler);
    }

    public function off(event:String, handler:EventHandler):Void {
        if (!handlers.exists(event) || handler == null) return;
        handlers.get(event).remove(handler);
        if (handlers.get(event).length == 0) {
            handlers.remove(event);
        }
    }

    public function once(event:String, handler:EventHandler):Void {
        if (handler == null) return;
        var wrapper:EventHandler = null;
        wrapper = function(data:Dynamic) {
            off(event, wrapper);
            handler(data);
        };
        on(event, wrapper);
    }

    public function emit(event:String, ?data:Dynamic):Void {
        if (!handlers.exists(event)) return;

        // Copy array to prevent mutation errors if listeners remove themselves during dispatch
        var list = handlers.get(event).copy();
        for (handler in list) {
            if (handler != null) {
                handler(data);
            }
        }
    }

    public function clear(event:String):Void {
        handlers.remove(event);
    }

    public function clearAll():Void {
        handlers.clear();
    }

    // --- Static Convenience API ---

    public static inline function subscribe(event:String, handler:EventHandler):Void {
        instance.on(event, handler);
    }

    public static inline function unsubscribe(event:String, handler:EventHandler):Void {
        instance.off(event, handler);
    }

    public static inline function publish(event:String, ?data:Dynamic):Void {
        instance.emit(event, data);
    }
}