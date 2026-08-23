package soulscorch.scripting.backends;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.effects.FlxTrail;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.math.FlxVelocity;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import hscript.Interp;
import hscript.Parser;
import openfl.display.BlendMode;
import soulscorch.backend.MusicBeatState;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.PlayState;
import soulscorch.gameplay.actors.Character;
import soulscorch.gameplay.actors.HealthIcon;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.notes.StrumArrow;
import soulscorch.gameplay.notes.Strumline;
import soulscorch.graphics.JuiceManager;
import soulscorch.scripting.ScriptInstance;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.ModRegistry;
import soulscorch.scripting.soul.SoulScriptParser;

using StringTools;

class SoulScript implements ScriptInstance {
    public var active:Bool = false;
    public var path(default, null):String;

    private var interp:Interp;

    public var customSprites:Map<String, FlxSprite> = new Map<String, FlxSprite>();
    public var customTexts:Map<String, FlxText> = new Map<String, FlxText>();
    public var activeTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
    public var activeTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();

    public function new(scriptPath:String) {
        this.path = (scriptPath == null) ? "" : scriptPath;
        load();
    }

    public function load():Bool {
        var fullPath = ModManager.getPath(path);
        if (!AssetResolver.exists(fullPath)) {
            active = false;
            return false;
        }

        try {
            var rawText = AssetResolver.getText(fullPath);
            initScript(rawText, fullPath);
            active = true;
            return true;
        } catch (e:Dynamic) {
            Logger.error('Failed to initialize SoulScript ($path): $e', "soulscript");
            active = false;
            return false;
        }
    }

    private function initScript(code:String, fullPath:String):Void {
        var parsedCode = fullPath.endsWith(".soul") ? SoulScriptParser.transpile(code) : code;

        var parser = new Parser();
        parser.allowTypes = false; // Prevents numbers like 64 and 1 from failing as types
        parser.allowJSON = true;
        var program = parser.parseString(parsedCode);

        interp = new Interp();

        for (i in 0...2000) {
            interp.variables.set(Std.string(i), i);
        }

        set("Std", Std);
        set("Math", Math);
        set("StringTools", StringTools);
        set("FlxG", FlxG);
        set("FlxSprite", FlxSprite);
        set("FlxCamera", FlxCamera);
        set("FlxText", FlxText);
        set("FlxTween", FlxTween);
        set("FlxEase", FlxEase);
        set("FlxTimer", FlxTimer);
        set("FlxMath", FlxMath);
        set("FlxColor", {
            BLACK: 0xFF000000,
            WHITE: 0xFFFFFFFF,
            RED: 0xFFFF0000,
            GREEN: 0xFF00FF00,
            BLUE: 0xFF0000FF,
            TRANSPARENT: 0x00000000,
            fromRGB: FlxColor.fromRGB,
            fromString: FlxColor.fromString
        });

        set("Conductor", Conductor);
        set("Paths", Paths);
        set("AssetHelper", AssetHelper);

        set("Reflect", Reflect);
        set("Type", Type);
        set("Date", Date);
        set("Json", haxe.Json);
        set("Logger", Logger);
        set("ModManager", ModManager);
        set("ModRegistry", ModRegistry);

        set("FlxState", FlxState);
        set("FlxSubState", FlxSubState);
        set("FlxBasic", FlxBasic);
        set("FlxObject", FlxObject);
        set("FlxGroup", FlxGroup);
        set("FlxTypedGroup", FlxTypedGroup);
        set("FlxSpriteGroup", FlxSpriteGroup);
        set("FlxBar", FlxBar);
        set("FlxButton", FlxButton);
        set("FlxBackdrop", FlxBackdrop);
        set("FlxGridOverlay", FlxGridOverlay);
        set("FlxTrail", FlxTrail);
        set("FlxSound", FlxSound);
        set("FlxSort", FlxSort);
        set("FlxVelocity", FlxVelocity);
        set("FlxAngle", FlxAngle);
        set("FlxRect", {get: FlxRect.get});
        set("FlxPoint", {
            get: function(?x:Float = 0, ?y:Float = 0) return FlxPoint.get(x, y),
            weak: function(?x:Float = 0, ?y:Float = 0) return FlxPoint.weak(x, y),
            set: function(point:FlxPoint, ?x:Float = 0, ?y:Float = 0) return point.set(x, y)
        });

        set("Character", Character);
        set("HealthIcon", HealthIcon);
        set("Note", Note);
        set("StrumArrow", StrumArrow);

        set("BlendMode", BlendMode);

        // --- Extended API (no limits) ---
        set("add", function(obj:FlxBasic) {
            if (FlxG.state != null) FlxG.state.add(obj);
        });
        set("remove", function(obj:FlxBasic) {
            if (FlxG.state != null) FlxG.state.remove(obj);
        });
        set("insert", function(idx:Int, obj:FlxBasic) {
            if (FlxG.state != null) FlxG.state.insert(idx, obj);
        });

        set("makeLuaSprite", function(tag:String, ?image:String, x:Float = 0, y:Float = 0) {
            var spr = new FlxSprite(x, y);
            if (image != null && image != "") {
                if (AssetResolver.exists(image)) AssetHelper.loadGraphicSafely(spr, image);
                else spr.makeGraphic(1, 1, FlxColor.WHITE);
            } else {
                spr.makeGraphic(1, 1, FlxColor.WHITE);
            }
            customSprites.set(tag, spr);
            return spr;
        });

        set("makeGraphic", function(tag:String, width:Int, height:Int, colorStr:String = "0xFFFFFFFF") {
            var spr = customSprites.get(tag);
            if (spr == null) {
                spr = new FlxSprite();
                customSprites.set(tag, spr);
            }
            spr.makeGraphic(width, height, FlxColor.fromString(colorStr));
        });

        set("makeLuaText", function(tag:String, text:String, width:Float = 0, x:Float = 0, y:Float = 0) {
            var txt = new FlxText(x, y, width, text, 16);
            txt.setFormat(Paths.font("vcr"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
            customTexts.set(tag, txt);
            return txt;
        });

        set("addLuaSprite", function(tag:String, inFront:Bool = false) {
            var spr = customSprites.get(tag);
            if (spr != null && FlxG.state != null) {
                if (inFront) FlxG.state.add(spr); else FlxG.state.insert(0, spr);
            }
        });

        set("addLuaText", function(tag:String, inFront:Bool = false) {
            var txt = customTexts.get(tag);
            if (txt != null && FlxG.state != null) {
                if (inFront) FlxG.state.add(txt); else FlxG.state.insert(0, txt);
            }
        });

        set("setTextBorder", function(tag:String, size:Int, colorStr:String) {
            var txt = customTexts.get(tag);
            if (txt != null) {
                txt.borderSize = size;
                txt.borderColor = FlxColor.fromString(colorStr);
                txt.borderStyle = OUTLINE;
            }
        });

        set("setTextAlignment", function(tag:String, align:String) {
            var txt = customTexts.get(tag);
            if (txt != null) {
                txt.alignment = switch (align.toLowerCase().trim()) {
                    case "center" | "centre": CENTER;
                    case "right": RIGHT;
                    default: LEFT;
                };
            }
        });

        set("setTextWidth", function(tag:String, width:Float) {
            var txt = customTexts.get(tag);
            if (txt != null) txt.fieldWidth = width;
        });

        set("setObjectOrder", function(tag:String, order:Int) {
            var obj:FlxBasic = customSprites.exists(tag) ? customSprites.get(tag) : customTexts.get(tag);
            if (obj != null && FlxG.state != null) {
                FlxG.state.remove(obj);
                FlxG.state.insert(order, obj);
            }
        });

        set("getObjectOrder", function(tag:String):Int {
            var obj:FlxBasic = customSprites.exists(tag) ? customSprites.get(tag) : customTexts.get(tag);
            if (obj != null && FlxG.state != null) return FlxG.state.members.indexOf(obj);
            return -1;
        });

        set("objectPlayAnim", function(tag:String, anim:String, forced:Bool = false) {
            var spr = customSprites.get(tag);
            if (spr != null && spr.animation != null && spr.animation.exists(anim)) spr.animation.play(anim, forced);
        });

        set("setPropertyFromGroup", function(group:String, index:Int, variable:String, value:Dynamic) {
            var grp:Dynamic = get("game") != null ? get("game") : FlxG.state;
            var target:Dynamic = (grp != null) ? Reflect.getProperty(grp, group) : null;
            if (target != null && Reflect.field(target, "members") != null) {
                var members:Array<Dynamic> = Reflect.field(target, "members");
                if (index >= 0 && index < members.length) setProperty(members[index], variable, value);
            }
        });

        set("getPropertyFromGroup", function(group:String, index:Int, variable:String):Dynamic {
            var grp:Dynamic = get("game") != null ? get("game") : FlxG.state;
            var target:Dynamic = (grp != null) ? Reflect.getProperty(grp, group) : null;
            if (target != null && Reflect.field(target, "members") != null) {
                var members:Array<Dynamic> = Reflect.field(target, "members");
                if (index >= 0 && index < members.length) return getProperty(members[index], variable);
            }
            return null;
        });

        set("runTimer", function(tag:String, time:Float, ?func:String = "onTimerCompleted", loops:Int = 1) {
            this.cancelTimer(tag);
            var remaining = loops;
            var cb = function(_:FlxTimer) {
                call(func, [tag, Std.string(loops - remaining)]);
                remaining--;
                if (remaining <= 0) activeTimers.remove(tag);
            };
            activeTimers.set(tag, new FlxTimer().start(time, cb, loops));
        });

        set("cancelTimer", function(tag:String) {
            this.cancelTimer(tag);
        });

        set("cancelTween", function(tag:String) {
            this.cancelTween(tag);
        });

        set("screenCenter", function(tag:String, axis:String = "xy") {
            var obj:FlxSprite = customSprites.exists(tag) ? customSprites.get(tag) : customTexts.get(tag);
            if (obj != null) {
                var a = axis.toLowerCase().trim();
                if (a == "x") obj.screenCenter(X);
                else if (a == "y") obj.screenCenter(Y);
                else obj.screenCenter();
            }
        });

        set("setBlendMode", function(tag:String, blend:String) {
            var obj:FlxSprite = customSprites.exists(tag) ? customSprites.get(tag) : customTexts.get(tag);
            if (obj != null) {
                obj.blend = switch (blend.toLowerCase().trim()) {
                    case "add": BlendMode.ADD;
                    case "subtract": BlendMode.SUBTRACT;
                    case "multiply": BlendMode.MULTIPLY;
                    case "screen": BlendMode.SCREEN;
                    case "erase": BlendMode.ERASE;
                    default: BlendMode.NORMAL;
                };
            }
        });

        set("setPropertyFromState", function(obj:String, prop:String, val:Dynamic) {
            if (FlxG.state != null) setProperty(FlxG.state, '$obj.$prop', val);
        });

        set("getPropertyFromState", function(obj:String, prop:String):Dynamic {
            return (FlxG.state != null) ? getProperty(FlxG.state, '$obj.$prop') : null;
        });

        set("isModEnabled", function(mod:String):Bool {
            return ModRegistry.instance.isEnabled(mod);
        });

        set("getActiveMods", function():Array<String> {
            return ModRegistry.instance.enabledMods;
        });

        set("debugPrint", function(msg:Dynamic) {
            Logger.info('[SOULSCRIPT] $msg', "soulscript");
        });

        set("playSound", function(soundPath:String, volume:Float = 1.0) {
            AssetHelper.playSoundSafely(soundPath, volume);
        });

        syncStateVariables();
        interp.execute(program);
    }

    public function syncStateVariables():Void {
        var ps = PlayState.instance;
        set("game", (ps != null) ? ps : FlxG.state);
        set("state", FlxG.state);

        if (ps != null) {
            set("boyfriend", ps.boyfriend);
            set("dad", ps.dad);
            set("gf", ps.gf);
            set("camGame", ps.camGame);
            set("camHUD", ps.camHUD);
            set("playerStrumline", ps.playerStrumline);
            set("opponentStrumline", ps.opponentStrumline);
            set("playerStrums", (ps.playerStrumline != null) ? ps.playerStrumline.receptors : null);
            set("opponentStrums", (ps.opponentStrumline != null) ? ps.opponentStrumline.receptors : null);
            set("notes", ps.notes);
            set("sustainsGroup", ps.sustainsGroup);
            set("health", ps.health);
        }
    }

    public function call(func:String, ?args:Array<Dynamic>):Dynamic {
        if (!active || interp == null) return null;

        set("curBeat", Conductor.curBeat);
        set("curStep", Conductor.curStep);
        set("songPosition", Conductor.songPosition);

        if (interp.variables.exists(func)) {
            var fn = interp.variables.get(func);
            if (fn != null && Reflect.isFunction(fn)) {
                try {
                    return Reflect.callMethod(null, fn, (args != null) ? args : []);
                } catch (e:Dynamic) {
                    Logger.warn('SoulScript call warning in $func ($path): $e', "soulscript");
                }
            }
        }
        return null;
    }

    public function set(key:String, value:Dynamic):Void {
        if (interp != null) interp.variables.set(key, value);
    }

    public function get(key:String):Dynamic {
        return (interp != null && interp.variables.exists(key)) ? interp.variables.get(key) : null;
    }

    public function importClass(className:String):Bool {
        if (interp == null || className == null) return false;
        var resolvedClass:Dynamic = Type.resolveClass(className);
        if (resolvedClass != null) {
            set(className.substr(className.lastIndexOf(".") + 1), resolvedClass);
            return true;
        }
        return false;
    }

    public static function setProperty(root:Dynamic, dottedPath:String, value:Dynamic):Void {
        if (root == null || dottedPath == null) return;
        var parts = dottedPath.split(".");
        var current = root;
        for (i in 0...parts.length - 1) {
            if (current == null) return;
            current = Reflect.getProperty(current, parts[i]);
        }
        if (current != null) Reflect.setProperty(current, parts[parts.length - 1], value);
    }

    public static function getProperty(root:Dynamic, dottedPath:String):Dynamic {
        if (root == null || dottedPath == null) return null;
        var parts = dottedPath.split(".");
        var current = root;
        for (p in parts) {
            if (current == null) return null;
            current = Reflect.getProperty(current, p);
        }
        return current;
    }

    public function cancelTimer(tag:String):Void {
        if (activeTimers.exists(tag)) {
            activeTimers.get(tag).cancel();
            activeTimers.remove(tag);
        }
    }

    public function cancelTween(tag:String):Void {
        if (activeTweens.exists(tag)) {
            activeTweens.get(tag).cancel();
            activeTweens.remove(tag);
        }
    }

    public function destroy():Void {
        active = false;
        for (t in activeTweens) t.cancel();
        for (tm in activeTimers) tm.cancel();
        activeTweens.clear();
        activeTimers.clear();

        for (s in customSprites) s.destroy();
        for (txt in customTexts) txt.destroy();
        customSprites.clear();
        customTexts.clear();

        if (interp != null) {
            interp.variables.clear();
            interp = null;
        }
    }
}