package soulscorch.backend.system;

import soulscorch.backend.utils.Logger;

using StringTools;

class CancellableEvent {
    public var name:String;
    public var data:Dynamic;
    public var cancelled(default, null):Bool = false;

    public function new(name:String, ?data:Dynamic) {
        this.name = name;
        this.data = data;
    }

    public inline function cancel():Void {
        this.cancelled = true;
    }
}

typedef EventListener = {
    var fn:Dynamic->Void;
    var priority:Int;
    var ?target:Dynamic;
}

class EventBus {
    public static var instance(get, null):EventBus;
    private static var _instance:EventBus;

    private var handlers:Map<String, Array<EventListener>> = new Map<String, Array<EventListener>>();
    public var debugLogging:Bool = false;

    public function new() {
        _instance = this;
    }

    public static inline function get_instance():EventBus {
        if (_instance == null) _instance = new EventBus();
        return _instance;
    }

    public function on(event:String, handler:Dynamic->Void, priority:Int = 0, ?target:Dynamic):Void {
        if (event == null || handler == null) return;
        var norm = event.toLowerCase().trim();

        if (!handlers.exists(norm)) {
            handlers.set(norm, []);
        }

        var list = handlers.get(norm);
        list.push({fn: handler, priority: priority, target: target});
        list.sort((a, b) -> b.priority - a.priority); // Higher priority fires first
    }

    public function off(event:String, handler:Dynamic->Void):Void {
        if (event == null || handler == null) return;
        var norm = event.toLowerCase().trim();

        if (!handlers.exists(norm)) return;
        var list = handlers.get(norm);

        for (i in 0...list.length) {
            if (list[i].fn == handler) {
                list.splice(i, 1);
                break;
            }
        }

        if (list.length == 0) handlers.remove(norm);
    }

    public function offTarget(target:Dynamic):Void {
        if (target == null) return;

        for (event => list in handlers) {
            var i = list.length - 1;
            while (i >= 0) {
                if (list[i].target == target) {
                    list.splice(i, 1);
                }
                i--;
            }
            if (list.length == 0) handlers.remove(event);
        }
    }

    public function once(event:String, handler:Dynamic->Void, priority:Int = 0):Void {
        if (event == null || handler == null) return;
        var norm = event.toLowerCase().trim();

        var wrapper:Dynamic->Void = null;
        wrapper = function(data:Dynamic) {
            off(norm, wrapper);
            handler(data);
        };
        on(norm, wrapper, priority);
    }

    public function emit(event:String, ?data:Dynamic):Bool {
        if (event == null) return true;
        var norm = event.toLowerCase().trim();

        if (!handlers.exists(norm)) return true;

        var evObj:CancellableEvent = (Std.isOfType(data, CancellableEvent)) 
            ? cast data 
            : new CancellableEvent(norm, data);

        var list = handlers.get(norm).copy();
        for (listener in list) {
            if (evObj.cancelled) break;
            try {
                listener.fn(evObj.data != null ? evObj.data : evObj);
            } catch (e:Dynamic) {
                Logger.error('Error executing event "$norm": $e', "events");
            }
        }

        return !evObj.cancelled;
    }

    public inline function clear(event:String):Void {
        if (event != null) handlers.remove(event.toLowerCase().trim());
    }

    public inline function clearAll():Void {
        handlers.clear();
    }

    public static inline function subscribe(event:String, handler:Dynamic->Void, priority:Int = 0, ?target:Dynamic):Void {
        instance.on(event, handler, priority, target);
    }

    public static inline function unsubscribe(event:String, handler:Dynamic->Void):Void {
        instance.off(event, handler);
    }

    public static inline function publish(event:String, ?data:Dynamic):Bool {
        return instance.emit(event, data);
    }
}