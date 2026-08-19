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
    private static var _isLogging:Bool = false;

    static inline var MAX_ENTRIES:Int = 300;

    public var entries:Array<LogEntry> = [];
    public var minLevel:LogLevel = TRACE;
    public var enabledChannels:Map<String, Bool> = new Map<String, Bool>();

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
        if (_isLogging) return;
        _isLogging = true;

        try {
            if (cast(level, Int) < cast(minLevel, Int)) {
                _isLogging = false;
                return;
            }
            if (enabledChannels.exists(channel) && !enabledChannels.get(channel)) {
                _isLogging = false;
                return;
            }

            var cleanMsg = (message != null) ? Std.string(message) : "";
            var timeStamp:Float = #if sys Sys.time() #else Date.now().getTime() / 1000.0 #end;
            var entry = new LogEntry(level, channel, cleanMsg, timeStamp);
            entries.push(entry);
            if (entries.length > MAX_ENTRIES) entries.shift();

            var prefix = switch (level) {
                case TRACE: "TRACE";
                case INFO:  "INFO";
                case WARN:  "WARN";
                case ERROR: "ERROR";
            };

            var formatted = '[$prefix][$channel] $cleanMsg';

            #if sys
            Sys.println(formatted);
            #else
            trace(formatted);
            #end

            if (DevConsole.instance != null) {
                DevConsole.instance.log(formatted);
            }
        } catch (e:Dynamic) {}

        _isLogging = false;
    }

    public function setChannelEnabled(channel:String, enabled:Bool):Void {
        enabledChannels.set(channel, enabled);
    }

    public function clear():Void {
        entries = [];
    }

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