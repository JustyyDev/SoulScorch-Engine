package soulscorch.backend.system;

import soulscorch.backend.utils.Logger;

typedef EventHandler = Dynamic->Void;

class EventBus {
    public static var instance(get, null):EventBus;
    private static var _instance:EventBus;

    private var handlers:Map<String, Array<EventHandler>> = new Map<String, Array<EventHandler>>();

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
        if (event == null || handler == null) return;
        var norm = event.toLowerCase().trim();

        if (!handlers.exists(norm)) {
            handlers.set(norm, []);
        }
        var list = handlers.get(norm);
        if (!list.contains(handler)) {
            list.push(handler);
        }
    }

    public function off(event:String, handler:EventHandler):Void {
        if (event == null || handler == null) return;
        var norm = event.toLowerCase().trim();

        if (!handlers.exists(norm)) return;
        var list = handlers.get(norm);
        list.remove(handler);

        if (list.length == 0) {
            handlers.remove(norm);
        }
    }

    public function once(event:String, handler:EventHandler):Void {
        if (event == null || handler == null) return;
        var norm = event.toLowerCase().trim();

        var wrapper:EventHandler = null;
        wrapper = function(data:Dynamic) {
            off(norm, wrapper);
            handler(data);
        };
        on(norm, wrapper);
    }

    public function emit(event:String, ?data:Dynamic):Void {
        if (event == null) return;
        var norm = event.toLowerCase().trim();

        if (!handlers.exists(norm)) return;

        var list = handlers.get(norm).copy();
        for (handler in list) {
            if (handler != null) {
                try {
                    handler(data);
                } catch (e:Dynamic) {
                    Logger.error('Error executing event handler for "$norm": $e', "events");
                }
            }
        }
    }

    public function clear(event:String):Void {
        if (event == null) return;
        handlers.remove(event.toLowerCase().trim());
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

    public static inline function emitEvent(event:String, ?data:Dynamic):Void {
        instance.emit(event, data);
    }
}