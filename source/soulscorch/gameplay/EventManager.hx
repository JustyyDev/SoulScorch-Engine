package soulscorch.gameplay;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import soulscorch.core.EventBus;
import soulscorch.modding.ModManager;
import soulscorch.modding.ScriptCore;

private typedef QueuedEvent = {
    var time:Float;
    var type:String;
    var data:Dynamic;
    var fired:Bool;
}

class EventManager {
    public var camera:FlxCamera;
    public var events:Array<QueuedEvent> = [];
    public var opponentPosition:{x:Float, y:Float} = {x: 400.0, y: 300.0};
    public var playerPosition:{x:Float, y:Float} = {x: 900.0, y: 300.0};
    public var stageCenter:{x:Float, y:Float} = {x: 650.0, y: 300.0};
    public var script:ScriptCore;
    public var cameraZoom:Float = 1.0;
    private var zoomBump:Float = 0.0;

    public function new(?camera:FlxCamera, ?scriptPath:String) {
        this.camera = camera == null ? FlxG.camera : camera;
        if (scriptPath != null && scriptPath.length > 0) {
            var resolved:String = ModManager.getPath(scriptPath);
            script = new ScriptCore(resolved);
        }
    }

    public function parse(raw:Dynamic):Void {
        if (raw == null) return;
        var source:Dynamic = Reflect.hasField(raw, "events") ? Reflect.field(raw, "events") : raw;
        if (!Std.isOfType(source, Array)) return;
        for (entry in (cast source:Array<Dynamic>)) {
            if (entry == null) continue;
            var time:Float = number(entry, "time", number(entry, "strumTime", 0.0));
            var type:String = string(entry, "type", string(entry, "name", ""));
            var data:Dynamic = Reflect.hasField(entry, "data") ? Reflect.field(entry, "data") : entry;
            if (type.length > 0) events.push({time: time, type: type, data: data, fired: false});
        }
        events.sort(function(a:QueuedEvent, b:QueuedEvent):Int return a.time < b.time ? -1 : a.time > b.time ? 1 : 0);
    }

    public function update(songPosition:Float, elapsed:Float):Void {
        for (event in events) {
            if (!event.fired && event.time <= songPosition) {
                event.fired = true;
                dispatch(event.type, event.data);
            }
        }
        if (zoomBump > 0.0) zoomBump = Math.max(0.0, zoomBump - elapsed * 2.5);
        camera.zoom = cameraZoom + zoomBump;
    }

    public function beatHit(beat:Int):Void {
        if (beat < 0) return;
        if (zoomBump > 0.0) zoomBump = 0.0;
        zoomBump = 0.04;
        EventBus.publish("event/beat-bump", {beat: beat});
    }

    public function reset():Void for (event in events) event.fired = false;

    private function dispatch(type:String, data:Dynamic):Void {
        var normalized:String = type.toLowerCase();
        switch (normalized) {
            case "camera pan", "camera_pan", "camerapan": panCamera(string(data, "target", "stage"), number(data, "duration", 0.35));
            case "camera zoom", "camera_zoom", "camerazoom": zoom(number(data, "amount", 0.05), number(data, "duration", 0.25));
            case "camera bump", "camera_bump", "camerabump": zoomBump += number(data, "amount", 0.05);
            case "flash", "flash screen": FlxG.camera.flash(colorInt(data, "color", 0xFFFFFFFF), number(data, "duration", 0.25));
            case "fade", "fade screen": FlxG.camera.fade(colorInt(data, "color", 0xFF000000), number(data, "duration", 0.5), bool(data, "hold", false));
            case "hscript", "hscript trigger", "script": triggerScript(string(data, "function", string(data, "hook", "onEvent")), data);
            default: EventBus.publish("event/custom", {type: type, data: data});
        }
        EventBus.publish("event/dispatched", {type: type, data: data});
    }

    private function panCamera(target:String, duration:Float):Void {
        var point:{x:Float, y:Float} = switch (target.toLowerCase()) {
            case "opponent", "dad": opponentPosition;
            case "player", "bf": playerPosition;
            default: stageCenter;
        };
        FlxTween.tween(camera.scroll, {x: point.x, y: point.y}, Math.max(0.01, duration), {ease: FlxEase.quadOut});
    }

    private function zoom(amount:Float, duration:Float):Void {
        cameraZoom += amount;
        FlxTween.tween(camera, {zoom: cameraZoom}, Math.max(0.01, duration), {ease: FlxEase.quadOut});
    }

    private function triggerScript(functionName:String, data:Dynamic):Void {
        if (script != null && script.active) script.call(functionName, [data]);
    }

    private static function number(value:Dynamic, name:String, fallback:Float):Float {
        if (value == null || !Reflect.hasField(value, name)) return fallback;
        var field:Dynamic = Reflect.field(value, name);
        return field == null ? fallback : Std.parseFloat(Std.string(field));
    }

    private static function string(value:Dynamic, name:String, fallback:String):String return value != null && Reflect.hasField(value, name) && Reflect.field(value, name) != null ? Std.string(Reflect.field(value, name)) : fallback;
    private static function bool(value:Dynamic, name:String, fallback:Bool):Bool return value != null && Reflect.hasField(value, name) ? cast Reflect.field(value, name) : fallback;
    private static function colorInt(value:Dynamic, name:String, fallback:Int):Int return Std.int(number(value, name, fallback));
}
