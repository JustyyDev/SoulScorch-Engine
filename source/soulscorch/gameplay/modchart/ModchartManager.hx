package soulscorch.gameplay.modchart;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import haxe.Timer;
import soulscorch.backend.audio.Conductor;
import soulscorch.gameplay.GameplayFlags;
import soulscorch.gameplay.modchart.ModchartEase;
import soulscorch.gameplay.modchart.ModchartTypes;
import soulscorch.gameplay.modchart.Modifiers;
import soulscorch.gameplay.notes.Note;
import soulscorch.gameplay.notes.StrumArrow;

using StringTools;

class ModchartManager {
    public static var instance:ModchartManager;

    public var playerStrumline:Dynamic;
    public var opponentStrumline:Dynamic;

    public var modifierObjects:Map<String, Modifier> = new Map<String, Modifier>();
    private var modifierList:Array<Modifier> = [];
    public var events:Array<ModchartEvent> = [];
    private var eventCursor:Int = 0;
    public var totalTime:Float = 0.0;
    public var lastUpdateMs(default, null):Float = 0.0;
    public var averageUpdateMs(default, null):Float = 0.0;
    public var peakUpdateMs(default, null):Float = 0.0;
    private var modifierTweens:Array<FlxTween> = [];
    private var _updateSampleCount:Int = 0;
    private var _playerReceptorsCache:Array<Dynamic> = [];
    private var _opponentReceptorsCache:Array<Dynamic> = [];
    private var _playerHasBaseField:Array<Bool> = [];
    private var _opponentHasBaseField:Array<Bool> = [];
    private var _lastLowEndState:Bool = false;
    private var _lowEndMultiplier:Float = 1.0;
    private var _lastPolicyCheckTime:Float = -1.0;

    private static inline var EVENT_COMPACT_THRESHOLD:Int = 256;

    public function new(playerStrums:Dynamic, opponentStrums:Dynamic) {
        instance = this;
        this.playerStrumline = playerStrums;
        this.opponentStrumline = opponentStrums;

        registerBuiltinModifiers();
    }

    private function registerBuiltinModifiers():Void {
        registerModifier(new DrunkModifier());
        registerModifier(new TipsyModifier());
        registerModifier(new BumpyModifier());
        registerModifier(new TornadoModifier());
        registerModifier(new ConfusionModifier());
        registerModifier(new StealthModifier());
        registerModifier(new InvertModifier());
        registerModifier(new FlipModifier());
        registerModifier(new MiniModifier());
        registerModifier(new SpinModifier());
        registerModifier(new WaveModifier());
        registerModifier(new SquareModifier());
        registerModifier(new CrossoverModifier());
        registerModifier(new XModifier());
        registerModifier(new YModifier());
        registerModifier(new AlphaModifier());
        registerModifier(new DrawDistanceModifier());
        registerModifier(new PulseModifier());
    }

    public function registerModifier(mod:Modifier):Void {
        if (mod != null && mod.name != null) {
            var key = mod.name.toLowerCase().trim();
            if (!modifierObjects.exists(key)) {
                modifierList.push(mod);
            }
            modifierObjects.set(key, mod);
        }
    }

    public function set(name:String, value:Float, target:ModTarget = BOTH, lane:Int = -1):Void {
        var clean = (name != null) ? name.toLowerCase().trim() : "";
        if (modifierObjects.exists(clean)) {
            modifierObjects.get(clean).setValue(value, target, lane);
        }
    }

    public function get(name:String, target:ModTarget = PLAYER, lane:Int = 0):Float {
        var clean = (name != null) ? name.toLowerCase().trim() : "";
        return modifierObjects.exists(clean) ? modifierObjects.get(clean).getValue(target, lane) : 0.0;
    }

    public function queueEvent(step:Float, name:String, value:Float, duration:Float = 0, ease:String = "linear", target:ModTarget = BOTH, lane:Int = -1):Void {
        var ev:ModchartEvent = {
            step: step,
            name: name,
            value: value,
            duration: duration,
            ease: ease,
            target: target,
            lane: lane
        };

        var low = eventCursor;
        var high = events.length;
        while (low < high) {
            var mid = low + ((high - low) >> 1);
            if (events[mid].step <= step) low = mid + 1; else high = mid;
        }
        events.insert(low, ev);
    }

    public function update(elapsed:Float):Void {
        var updateStart = Timer.stamp();
        totalTime += elapsed;
        applyLowEndPolicy();

        for (mod in modifierList) {
            if (mod.active) mod.update(elapsed);
        }

        var stepCrochet = Conductor.stepCrochet > 0 ? Conductor.stepCrochet : 150.0;
        var curStepFloat = Conductor.songPosition / stepCrochet;

        while (eventCursor < events.length && events[eventCursor].step <= curStepFloat) {
            var ev = events[eventCursor++];
            if (ev.duration <= 0) {
                set(ev.name, ev.value, ev.target, ev.lane);
            } else {
                tweenModifier(ev.name, ev.value, ev.duration * stepCrochet * 0.001, ev.ease, ev.target, ev.lane);
            }
        }

        if (eventCursor >= EVENT_COMPACT_THRESHOLD && eventCursor >= Std.int(events.length * 0.5)) {
            events = events.slice(eventCursor);
            eventCursor = 0;
        }

        updateReceptors(PLAYER);
        updateReceptors(OPPONENT);

        lastUpdateMs = (Timer.stamp() - updateStart) * 1000.0;
        _updateSampleCount++;
        averageUpdateMs += (lastUpdateMs - averageUpdateMs) / _updateSampleCount;
        if (lastUpdateMs > peakUpdateMs) peakUpdateMs = lastUpdateMs;
    }

    private function tweenModifier(name:String, targetVal:Float, duration:Float, easeName:String, target:ModTarget, lane:Int = -1):Void {
        if (_lowEndMultiplier < 1.0) {
            targetVal *= _lowEndMultiplier;
        }
        var startVal = get(name, target, lane >= 0 ? lane : 0);
        var easeFn = ModchartEase.getEase(easeName);

        var tween = FlxTween.num(startVal, targetVal, Math.max(0.001, duration), {ease: easeFn}, function(v:Float) {
            set(name, v, target, lane);
        });
        modifierTweens.push(tween);
    }

    private function updateReceptors(target:ModTarget):Void {
        var receptors = getReceptorListCached(target);
        if (receptors == null) return;

        var hasBaseList = (target == OPPONENT) ? _opponentHasBaseField : _playerHasBaseField;

        for (i in 0...receptors.length) {
            var receptor:FlxSprite = receptors[i];
            if (receptor == null) continue;

            var hasBase = (i < hasBaseList.length) ? hasBaseList[i] : false;
            var baseX:Float = hasBase ? Reflect.field(receptor, "baseX") : receptor.x;
            var baseY:Float = hasBase ? Reflect.field(receptor, "baseY") : receptor.y;

            receptor.x = baseX;
            receptor.y = baseY;
            receptor.angle = 0;
            receptor.alpha = 1.0;
            receptor.scale.set(1.0, 1.0);

            for (mod in modifierList) {
                if (mod.active) {
                    mod.modifyReceptor(receptor, i, target);
                }
            }
        }
    }

    public function modifyNote(note:Note, dir:Int, target:ModTarget, strumTime:Float):Void {
        if (note == null) return;

        for (mod in modifierList) {
            if (mod.active) {
                mod.modifyNote(note, dir, target, strumTime);
            }
        }
    }

    private function getReceptorList(target:ModTarget):Array<Dynamic> {
        var targetLine = (target == OPPONENT) ? opponentStrumline : playerStrumline;
        if (targetLine == null) return [];

        if (Reflect.hasField(targetLine, "receptors")) {
            var list:Array<Dynamic> = Reflect.field(targetLine, "receptors");
            if (list != null) return list;
        }

        if (Std.isOfType(targetLine, FlxTypedGroup)) {
            var group:FlxTypedGroup<Dynamic> = cast targetLine;
            return group.members;
        }

        return [];
    }

    private function refreshReceptorCache(target:ModTarget):Array<Dynamic> {
        var list = getReceptorList(target);
        if (list == null) list = [];

        var targetCache = (target == OPPONENT) ? _opponentReceptorsCache : _playerReceptorsCache;
        targetCache.resize(0);
        for (i in 0...list.length) {
            targetCache.push(list[i]);
        }

        var hasBaseList = (target == OPPONENT) ? _opponentHasBaseField : _playerHasBaseField;
        hasBaseList.resize(0);
        for (i in 0...targetCache.length) {
            var receptor:Dynamic = targetCache[i];
            hasBaseList.push(receptor != null && Reflect.hasField(receptor, "baseX") && Reflect.hasField(receptor, "baseY"));
        }

        return targetCache;
    }

    private function getReceptorListCached(target:ModTarget):Array<Dynamic> {
        var cache = (target == OPPONENT) ? _opponentReceptorsCache : _playerReceptorsCache;
        if (cache == null || cache.length == 0) {
            return refreshReceptorCache(target);
        }

        // Detect basic receptor count changes and refresh when needed.
        var targetLine = (target == OPPONENT) ? opponentStrumline : playerStrumline;
        if (targetLine != null && Reflect.hasField(targetLine, "receptors")) {
            var live:Array<Dynamic> = Reflect.field(targetLine, "receptors");
            if (live != null && live.length != cache.length) {
                return refreshReceptorCache(target);
            }
        }

        return cache;
    }

    public function clear():Void {
        for (tween in modifierTweens) {
            if (tween != null) tween.cancel();
        }
        modifierTweens = [];
        events = [];
        eventCursor = 0;
        _playerReceptorsCache = [];
        _opponentReceptorsCache = [];
        _playerHasBaseField = [];
        _opponentHasBaseField = [];
        for (mod in modifierList) {
            mod.setValue(0.0, BOTH);
        }

        lastUpdateMs = 0.0;
        averageUpdateMs = 0.0;
        peakUpdateMs = 0.0;
        _updateSampleCount = 0;
    }

    private function applyLowEndPolicy():Void {
        if (Conductor.songPosition - _lastPolicyCheckTime < 250.0) return;
        _lastPolicyCheckTime = Conductor.songPosition;

        var lowEnd = GameplayFlags.getBool("lowEndMode", false) || GameplayFlags.getBool("lowQuality", false);
        var targetMultiplier = lowEnd ? 0.75 : 1.0;

        if (lowEnd == _lastLowEndState && targetMultiplier == _lowEndMultiplier) return;

        _lastLowEndState = lowEnd;
        _lowEndMultiplier = targetMultiplier;

        // Disable the heaviest visual modifiers in low-end mode.
        for (mod in modifierList) {
            if (mod == null || mod.name == null) continue;
            var modName = mod.name.toLowerCase().trim();
            if (lowEnd) {
                mod.active = !(modName == "drunk" || modName == "tipsy" || modName == "tornado" || modName == "square" || modName == "wave");
            } else {
                mod.active = true;
            }
        }
    }
}