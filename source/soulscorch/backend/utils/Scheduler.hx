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

    public function cancel():Void {
        this.alive = false;
    }
}

class Scheduler {
    public static var instance(get, null):Scheduler;
    private static var _instance:Scheduler;

    private var tasks:Array<ScheduledTask> = [];
    private static inline var MAX_REPEAT_CATCHUP_PER_FRAME:Int = 8;

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
        if (tasks.length == 0) return;

        var writeIndex:Int = 0;
        for (readIndex in 0...tasks.length) {
            var task = tasks[readIndex];
            if (task == null || !task.alive) continue;

            task.remaining -= elapsed;
            if (task.remaining <= 0) {
                if (task.repeat) {
                    var triggerCount:Int = 0;
                    while (task.alive && task.remaining <= 0 && triggerCount < MAX_REPEAT_CATCHUP_PER_FRAME) {
                        if (task.callback != null) task.callback();
                        triggerCount++;
                        task.remaining += task.interval;
                    }

                    if (task.interval <= 0) {
                        task.alive = false;
                    }
                } else {
                    if (task.callback != null) task.callback();
                    task.alive = false;
                }
            }

            if (task.alive) {
                tasks[writeIndex++] = task;
            }
        }

        if (writeIndex < tasks.length) {
            tasks.resize(writeIndex);
        }
    }

    public function clear():Void {
        for (t in tasks) t.alive = false;
        tasks = [];
    }
}