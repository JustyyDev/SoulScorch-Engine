package soulscorch.backend;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxState;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.TransitionData;
import soulscorch.backend.TransitionData.TransitionDirection;
import soulscorch.backend.TransitionData.TransitionType;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.interfaces.IBeatReceiver;
import soulscorch.backend.system.Scene;
import soulscorch.backend.system.XMSoul;
import soulscorch.scripting.ScriptedState;

using StringTools;

class MusicBeatState extends Scene implements IBeatReceiver {
    public static var defaultTransition:TransitionData = new TransitionData(TransitionType.WIPE, TransitionDirection.OUT, 0.35);
    public static var skipNextTransIn:Bool = false;
    public static var skipNextTransOut:Bool = false;
    public static var nextStateTarget:FlxState = null;
    private static var _transitionsLoaded:Bool = false;
    private static var _customStateExistsCache:Map<String, Bool> = new Map<String, Bool>();

    override public function create():Void {
        super.create();

        loadCustomTransitions();

        if (!skipNextTransIn) {
            MusicBeatTransition.play(new TransitionData(
                defaultTransition.type, 
                TransitionDirection.IN, 
                defaultTransition.duration, 
                defaultTransition.color, 
                defaultTransition.ease,
                defaultTransition.sound
            ));
        }
        skipNextTransIn = false;
    }

    public static function loadCustomTransitions():Void {
        if (_transitionsLoaded) return;

        var access:Access = XMSoul.parse("config/transitions");
        if (access == null) access = XMSoul.parse("data/config/transitions");

        if (access != null) {
            var typeStr = XMSoul.getAttr(access, "type", "wipe");
            var duration = XMSoul.getFloatAttr(access, "duration", 0.35);
            var easeStr = XMSoul.getAttr(access, "ease", "quartOut");
            var colStr = XMSoul.getAttr(access, "color", "0xFF000000");
            var sfx = XMSoul.getAttr(access, "sound", null);

            var color = FlxColor.fromString(colStr);
            defaultTransition = new TransitionData(
                TransitionData.parseType(typeStr),
                TransitionDirection.OUT,
                duration,
                color != null ? color : FlxColor.BLACK,
                TransitionData.parseEase(easeStr),
                sfx
            );
        }

        _transitionsLoaded = true;
    }

    public static function switchState(nextState:FlxState, ?transData:TransitionData):Void {
        if (nextState == null) return;
        if (MusicBeatTransition.isTransitioning) return;

        var transition = transData != null ? transData : defaultTransition;

        var nextClass = Type.getClass(nextState);
        var fullStateName = nextClass != null ? Type.getClassName(nextClass) : "";
        var stateName:String = fullStateName != null ? fullStateName.split(".").pop() : "";
        var redirectTarget:Null<String> = soulscorch.scripting.mod.SoulGlobalScript.getRedirect(stateName);

        // Only redirect if an explicit mapping exists that differs from the base state and exists on disk
        var finalTarget:FlxState = nextState;
        if (redirectTarget != null && redirectTarget != stateName) {
            if (hasCustomStateDefinition(redirectTarget)) {
                finalTarget = new ScriptedState(redirectTarget);
            }
        }

        if (skipNextTransOut || transition.type == NONE || FlxG.state == null) {
            skipNextTransOut = false;
            MusicBeatTransition.isTransitioning = false;
            FlxG.switchState(finalTarget);
            return;
        }

        nextStateTarget = finalTarget;
        MusicBeatTransition.play(transition, function() {
            FlxG.switchState(nextStateTarget);
            nextStateTarget = null;
        });
    }

    public static function resetState(?transData:TransitionData):Void {
        if (FlxG.state == null) return;
        var curClass = Type.getClass(FlxG.state);
        switchState(Type.createInstance(curClass, []), transData);
    }

    private static function hasCustomStateDefinition(stateName:String):Bool {
        if (stateName == null || stateName.trim().length == 0) return false;

        var clean = stateName.trim();
        if (_customStateExistsCache.exists(clean)) {
            return _customStateExistsCache.get(clean);
        }

        var exists = false;
        var scriptBases = [
            'states/$clean',
            'data/states/$clean',
            'scripts/states/$clean',
            'data/ui/$clean',
            'data/$clean'
        ];

        for (base in scriptBases) {
            if (AssetResolver.resolveFile(base, [".hx", ".hscript", ".iris", ".soul", ".lua", ".py", ".js", ""]) != null) {
                exists = true;
                break;
            }
        }

        if (!exists) {
            var layoutBases = [
                'states/$clean',
                'data/states/$clean',
                'data/ui/$clean',
                'data/$clean'
            ];

            for (base in layoutBases) {
                if (AssetResolver.resolveFile(base, [".xmsoul", ".xml", ""]) != null) {
                    exists = true;
                    break;
                }
            }
        }

        _customStateExistsCache.set(clean, exists);
        return exists;
    }
}