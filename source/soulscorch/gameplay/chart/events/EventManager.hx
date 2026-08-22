package soulscorch.gameplay.chart.events;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.events.SongEvents.QueuedEvent;
import soulscorch.graphics.JuiceManager;
import soulscorch.scripting.ScriptManager;

using StringTools;

class EventManager {
    public static var instance:EventManager;

    public var camera:FlxCamera;
    public var camHUD:FlxCamera;
    public var events:Array<QueuedEvent> = [];

    public var opponentPosition:{x:Float, y:Float} = {x: 400.0, y: 300.0};
    public var playerPosition:{x:Float, y:Float} = {x: 900.0, y: 300.0};
    public var gfPosition:{x:Float, y:Float} = {x: 650.0, y: 300.0};
    public var stageCenter:{x:Float, y:Float} = {x: 650.0, y: 300.0};

    public var baseCameraZoom:Float = 1.0;
    public var currentZoomOffset:Float = 0.0;
    private var zoomBump:Float = 0.0;

    public var onCameraPan:String->Float->Void;
    public var onPlayAnimation:String->String->Void;
    public var onSpeedChange:Float->Float->Void;

    public function new(?targetCamera:FlxCamera, ?hudCamera:FlxCamera) {
        instance = this;
        this.camera = (targetCamera != null) ? targetCamera : FlxG.camera;
        this.camHUD = hudCamera;
    }

    public function parse(raw:Dynamic):Void {
        if (raw == null) return;
        events = [];

        var rawList:Dynamic = Reflect.hasField(raw, "events") ? Reflect.field(raw, "events") : raw;
        if (!Std.isOfType(rawList, Array)) return;

        for (entry in (cast rawList : Array<Dynamic>)) {
            if (entry == null) continue;

            // Format A: Psych Engine array format: [time, [[name, val1, val2]]]
            if (Std.isOfType(entry, Array) && entry.length >= 2) {
                var time:Float = Std.parseFloat(Std.string(entry[0]));
                var subEvents:Array<Dynamic> = cast entry[1];
                if (subEvents != null) {
                    for (sub in subEvents) {
                        if (sub != null && sub.length >= 1) {
                            events.push({
                                time: time,
                                name: Std.string(sub[0]),
                                val1: sub.length > 1 ? Std.string(sub[1]) : "",
                                val2: sub.length > 2 ? Std.string(sub[2]) : "",
                                fired: false
                            });
                        }
                    }
                }
            } 
            // Format B: Codename Engine / JSON Object format
            else if (Reflect.hasField(entry, "name")) {
                var rawTime:Dynamic = Reflect.hasField(entry, "time") ? Reflect.field(entry, "time") : Reflect.field(entry, "strumTime");
                var time:Float = (rawTime != null) ? Std.parseFloat(Std.string(rawTime)) : 0.0;
                var name:String = Std.string(Reflect.field(entry, "name"));
                
                var val1:String = "";
                var val2:String = "";

                if (Reflect.hasField(entry, "params") && Reflect.field(entry, "params") != null) {
                    var params:Array<Dynamic> = cast Reflect.field(entry, "params");
                    if (params.length > 0 && params[0] != null) val1 = Std.string(params[0]);
                    if (params.length > 1 && params[1] != null) val2 = Std.string(params[1]);
                } else {
                    val1 = Reflect.hasField(entry, "val1") ? Std.string(Reflect.field(entry, "val1")) : (Reflect.hasField(entry, "data") ? Std.string(Reflect.field(entry, "data")) : "");
                    val2 = Reflect.hasField(entry, "val2") ? Std.string(Reflect.field(entry, "val2")) : "";
                }

                if (name.length > 0) {
                    events.push({
                        time: time,
                        name: name,
                        val1: val1,
                        val2: val2,
                        data: Reflect.field(entry, "data"),
                        fired: false
                    });
                }
            }
        }

        sortEvents();
    }

    public function addEvent(time:Float, name:String, val1:String = "", val2:String = ""):Void {
        events.push({
            time: time,
            name: name,
            val1: val1,
            val2: val2,
            fired: false
        });
        sortEvents();
    }

    public inline function sortEvents():Void {
        events.sort(function(a:QueuedEvent, b:QueuedEvent):Int {
            return (a.time < b.time) ? -1 : ((a.time > b.time) ? 1 : 0);
        });
    }

    public function update(songPosition:Float, elapsed:Float):Void {
        for (i in 0...events.length) {
            var event = events[i];
            if (!event.fired && event.time <= songPosition) {
                event.fired = true;
                dispatch(event.name, event.val1, event.val2, event.data);
            }
        }

        if (zoomBump > 0.0) {
            zoomBump = Math.max(0.0, zoomBump - (elapsed * 3.0));
            if (camera != null) {
                camera.zoom = baseCameraZoom + currentZoomOffset + zoomBump;
            }
        }
    }

    public function beatHit(beat:Int):Void {
        if (beat < 0) return;
        zoomBump = 0.035;
        EventBus.publish("event/beatBump", {beat: beat});
    }

    public function reset():Void {
        for (event in events) {
            event.fired = false;
        }
        zoomBump = 0.0;
    }

    private function dispatch(name:String, val1:String, val2:String, ?data:Dynamic):Void {
        var cleanName:String = name.toLowerCase().trim();

        switch (cleanName) {
            case "camera movement", "camera pan", "camera_pan", "camerapan", "focus camera":
                var target = (val1.length > 0) ? val1 : "stage";
                var duration = parseFloatSafe(val2, 0.4);
                panCamera(target, duration);

            case "camera zoom", "camera_zoom", "camerazoom", "set zoom", "set cam zoom":
                var zoomAmount = parseFloatSafe(val1, baseCameraZoom);
                var duration = parseFloatSafe(val2, 0.3);
                setCameraZoom(zoomAmount, duration);

            case "add camera zoom", "camera bump", "camerabump":
                var bumpAmount = parseFloatSafe(val1, 0.05);
                zoomBump += bumpAmount;

            case "screen shake", "screenshake", "shake":
                var intensity = parseFloatSafe(val1, 0.015);
                var duration = parseFloatSafe(val2, 0.25);
                if (camera != null) camera.shake(intensity, duration);

            case "flash", "flash screen", "screen flash":
                var duration = parseFloatSafe(val1, 0.35);
                var colorHex = parseColorSafe(val2, FlxColor.WHITE);
                if (camera != null) camera.flash(colorHex, duration);

            case "fade", "fade screen", "screen fade":
                var duration = parseFloatSafe(val1, 0.5);
                var colorHex = parseColorSafe(val2, FlxColor.BLACK);
                if (camera != null) camera.fade(colorHex, duration, false);

            case "play animation", "play anim":
                if (onPlayAnimation != null) {
                    onPlayAnimation(val1, val2);
                }

            case "change scroll speed", "scroll speed", "speed":
                var speedMultiplier = parseFloatSafe(val1, 1.0);
                var duration = parseFloatSafe(val2, 0.0);
                if (onSpeedChange != null) {
                    onSpeedChange(speedMultiplier, duration);
                }

            case "toggle ui", "ui alpha", "hud alpha":
                var targetAlpha = parseFloatSafe(val1, 1.0);
                var duration = parseFloatSafe(val2, 0.5);
                if (camHUD != null) {
                    FlxTween.tween(camHUD, {alpha: targetAlpha}, Math.max(0.01, duration), {ease: FlxEase.cubeOut});
                }

            case "script", "hscript", "call script":
                if (ScriptManager.instance != null) {
                    ScriptManager.instance.callAll(val1, [val2, data]);
                }

            default:
                EventBus.publish('event/$name', {val1: val1, val2: val2, data: data});
        }

        EventBus.publish("event/dispatched", {name: name, val1: val1, val2: val2, data: data});
        if (ScriptManager.instance != null) {
            ScriptManager.instance.callAll("onEvent", [name, val1, val2]);
        }
    }

    private function panCamera(target:String, duration:Float):Void {
        var point:{x:Float, y:Float} = switch (target.toLowerCase().trim()) {
            case "opponent", "dad", "0", "false": opponentPosition;
            case "player", "bf", "1", "true": playerPosition;
            case "gf", "girlfriend", "2": gfPosition;
            default: stageCenter;
        };

        if (onCameraPan != null) {
            onCameraPan(target, duration);
        } else if (camera != null) {
            FlxTween.tween(camera.scroll, {x: point.x - (FlxG.width * 0.5), y: point.y - (FlxG.height * 0.5)}, Math.max(0.01, duration), {
                ease: FlxEase.cubeOut
            });
        }
    }

    private function setCameraZoom(amount:Float, duration:Float):Void {
        baseCameraZoom = amount;
        if (camera != null) {
            FlxTween.tween(camera, {zoom: baseCameraZoom}, Math.max(0.01, duration), {
                ease: FlxEase.cubeOut
            });
        }
    }

    private static inline function parseFloatSafe(val:String, fallback:Float):Float {
        if (val == null || val.trim().length == 0) return fallback;
        var parsed = Std.parseFloat(val.trim());
        return Math.isNaN(parsed) ? fallback : parsed;
    }

    private static inline function parseColorSafe(val:String, fallback:FlxColor):FlxColor {
        if (val == null || val.trim().length == 0) return fallback;
        var parsed = FlxColor.fromString(val.trim());
        return parsed != null ? parsed : fallback;
    }
}