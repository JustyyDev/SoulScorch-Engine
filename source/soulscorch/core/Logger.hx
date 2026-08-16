package soulscorch.core;

import soulscorch.ui.DebugConsole;

/**
 * Engine logging system with severity levels, channel filtering, and a
 * ring-buffer of recent entries. Forwards to the debug console when present.
 */
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
    public static var instance(default, null):Logger;

    static inline var MAX_ENTRIES:Int = 250;

    public var entries:Array<LogEntry> = [];
    public var minLevel:LogLevel = TRACE;
    public var enabledChannels:Map<String, Bool> = new Map();

    public function new() {
        instance = this;
    }

    public function log(level:LogLevel, channel:String, message:String):Void {
        if (cast(level, Int) < cast(minLevel, Int)) return;
        if (enabledChannels.exists(channel) && !enabledChannels.get(channel)) return;

        var entry = new LogEntry(level, channel, message, Sys.time());
        entries.push(entry);
        if (entries.length > MAX_ENTRIES) entries.shift();

        var prefix = switch (level) {
            case TRACE: "TRACE";
            case INFO: "INFO";
            case WARN: "WARN";
            case ERROR: "ERROR";
        };

        Sys.println('[$prefix][$channel] $message');

        if (DebugConsole.instance != null) {
            DebugConsole.instance.log('[$prefix][$channel] $message');
        }
    }

    public function setChannelEnabled(channel:String, enabled:Bool):Void {
        enabledChannels.set(channel, enabled);
    }

    public function clear():Void {
        entries = [];
    }

    public static function trace(channel:String, message:String):Void {
        if (instance != null) instance.log(TRACE, channel, message);
        else Sys.println('[TRACE][$channel] $message');
    }

    public static function info(channel:String, message:String):Void {
        if (instance != null) instance.log(INFO, channel, message);
        else Sys.println('[INFO][$channel] $message');
    }

    public static function warn(channel:String, message:String):Void {
        if (instance != null) instance.log(WARN, channel, message);
        else Sys.println('[WARN][$channel] $message');
    }

    public static function error(channel:String, message:String):Void {
        if (instance != null) instance.log(ERROR, channel, message);
        else Sys.println('[ERROR][$channel] $message');
    }
}
