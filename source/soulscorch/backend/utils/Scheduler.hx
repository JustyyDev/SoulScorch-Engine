package soulscorch.backend.utils;

class ScheduledTask {
    public var remaining:Float;
    public var repeat:Bool;
    public var interval:Float;
    public var callback:Void->Void;
    public var alive:Bool = true;

    public function new(delay:Float, repeat:Bool, interval:Float, callback:Void->Void) {
        this.remaining = delay;
        this.repeat = repeat;
        this.interval = interval;
        this.callback = callback;
    }
}

class Scheduler {
    public static var instance(get, null):Scheduler;
    private static var _instance:Scheduler;

    var tasks:Array<ScheduledTask> = [];

    public function new() {
        _instance = this;
    }

    public static inline function get_instance():Scheduler {
        if (_instance == null) {
            _instance = new Scheduler();
        }
        return _instance;
    }

    public function after(delay:Float, callback:Void->Void):ScheduledTask {
        var task = new ScheduledTask(delay, false, delay, callback);
        tasks.push(task);
        return task;
    }

    public function every(interval:Float, callback:Void->Void):ScheduledTask {
        var task = new ScheduledTask(interval, true, interval, callback);
        tasks.push(task);
        return task;
    }

    public function cancel(task:ScheduledTask):Void {
        if (task != null) task.alive = false;
    }

    public function update(elapsed:Float):Void {
        for (task in tasks) {
            if (!task.alive) continue;
            task.remaining -= elapsed;
            if (task.remaining <= 0) {
                task.callback();
                if (task.repeat) {
                    task.remaining += task.interval;
                } else {
                    task.alive = false;
                }
            }
        }
        if (tasks.length > 0) {
            tasks = tasks.filter(function(t) return t.alive);
        }
    }

    public function clear():Void {
        tasks = [];
    }
}