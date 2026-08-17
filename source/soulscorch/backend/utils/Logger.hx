package soulscorch.backend.utils;

import soulscorch.backend.system.engine.DevConsole;

enum abstract LogLevel(Int) from Int to Int {
    var TRACE = 0;
    var INFO = 1;
    var WARN = 2;
    var ERROR = 3;
}

class LogEntry {
    public var level:LogLevel;
    public var channel:String;
    public var message:String;
    public var time:Float;

    public function new(level:LogLevel, channel:String, message:String, time:Float) {
        this.level = level;
        this.channel = channel;
        this.message = message;
        this.time = time;
    }
}

class Logger {
    public static var instance(get, null):Logger;
    private static var _instance:Logger;

    static inline var MAX_ENTRIES:Int = 250;

    public var entries:Array<LogEntry> = [];
    public var minLevel:LogLevel = TRACE;
    public var enabledChannels:Map<String, Bool> = new Map();

    public function new() {
        _instance = this;
    }

    public static inline function get_instance():Logger {
        if (_instance == null) {
            _instance = new Logger();
        }
        return _instance;
    }

    public function log(level:LogLevel, channel:String, message:String):Void {
        if (cast(level, Int) < cast(minLevel, Int)) return;
        if (enabledChannels.exists(channel) && !enabledChannels.get(channel)) return;

        var entry = new LogEntry(level, channel, message, Sys.time());
        entries.push(entry);
        if (entries.length > MAX_ENTRIES) entries.shift();

        var ansiColor = switch (level) {
            case TRACE: "\x1b[36m"; // Cyan
            case INFO:  "\x1b[32m"; // Green
            case WARN:  "\x1b[33m"; // Yellow
            case ERROR: "\x1b[31m"; // Red
        };

        var prefix = switch (level) {
            case TRACE: "TRACE";
            case INFO:  "INFO";
            case WARN:  "WARN";
            case ERROR: "ERROR";
        };

        Sys.println('$ansiColor[$prefix][$channel]\x1b[0m $message');

        if (DevConsole.instance != null) {
            DevConsole.instance.log('[$prefix][$channel] $message');
        }
    }

    public function setChannelEnabled(channel:String, enabled:Bool):Void {
        enabledChannels.set(channel, enabled);
    }

    public function clear():Void {
        entries = [];
    }

    // --- Static Convenience Methods ---

    public static function trace(message:Dynamic, ?channel:String = "engine"):Void {
        instance.log(TRACE, channel, Std.string(message));
    }

    public static function info(message:Dynamic, ?channel:String = "engine"):Void {
        instance.log(INFO, channel, Std.string(message));
    }

    public static function warn(message:Dynamic, ?channel:String = "engine"):Void {
        instance.log(WARN, channel, Std.string(message));
    }

    public static function error(message:Dynamic, ?channel:String = "engine"):Void {
        instance.log(ERROR, channel, Std.string(message));
    }
}