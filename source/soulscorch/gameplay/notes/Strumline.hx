package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import soulscorch.core.EventBus;
import soulscorch.modding.ModManager;
#if sys
import sys.FileSystem;
#end

class Strumline extends FlxTypedGroup<FlxSprite> {
    public var receptors:Array<FlxSprite> = [];
    public var autoplay:Bool = false;
    public var botplay:Bool = false;
    public var downscroll:Bool = false;
    public var laneSpacing:Float = 56.0;
    public var receptorY:Float = 100.0;
    private var activeNotes:FlxTypedGroup<Note>;
    private var confirmTimers:Array<Float> = [0.0, 0.0, 0.0, 0.0];

    public function new(x:Float = 0.0, y:Float = 100.0, ?notes:FlxTypedGroup<Note>) {
        super();
        receptorY = y;
        activeNotes = notes == null ? new FlxTypedGroup<Note>() : notes;
        for (lane in 0...4) {
            var receptor:FlxSprite = createReceptor(lane);
            receptor.x = x + lane * laneSpacing;
            receptor.y = y;
            receptors.push(receptor);
            add(receptor);
        }
    }

    private function createReceptor(lane:Int):FlxSprite {
        var receptor:FlxSprite = new FlxSprite();
        var path:String = ModManager.getPath("images/gameplay/notes/receptor.png");
        var loaded:Bool = false;
        #if sys
        if (path != null && FileSystem.exists(path)) loaded = receptor.loadGraphic(path, false, Note.NOTE_SIZE, Note.NOTE_SIZE) != null;
        #end
        if (!loaded) receptor.makeGraphic(Note.NOTE_SIZE, Note.NOTE_SIZE, Note.colorForLane(lane));
        receptor.alpha = 0.75;
        receptor.ID = lane;
        receptor.animation.add("static", [0], 0, false);
        receptor.animation.add("pressed", [0], 0, false);
        receptor.animation.add("confirm", [0], 0, false);
        receptor.animation.play("static");
        return receptor;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        for (lane in 0...4) {
            if (confirmTimers[lane] > 0.0) {
                confirmTimers[lane] -= elapsed;
                if (confirmTimers[lane] <= 0.0) setAnimation(lane, "static");
            }
        }
        if (autoplay || botplay) spawnAndConfirmNotes();
    }

    private function spawnAndConfirmNotes():Void {
        activeNotes.forEach(function(basic:flixel.FlxBasic):Void {
            var note:Note = cast basic;
            if (note == null || note.wasGoodHit || !note.canBeHit) return;
            note.wasGoodHit = true;
            confirm(note.noteData);
            EventBus.publish("strumline/autoplay", {lane: note.noteData, time: note.strumTime});
        });
    }

    public function press(lane:Int):Void {
        setAnimation(lane, "pressed");
        EventBus.publish("strumline/press", {lane: normalizeLane(lane)});
    }

    public function release(lane:Int):Void {
        setAnimation(lane, "static");
        EventBus.publish("strumline/release", {lane: normalizeLane(lane)});
    }

    public function confirm(lane:Int):Void {
        var normalized:Int = normalizeLane(lane);
        setAnimation(normalized, "confirm");
        confirmTimers[normalized] = 0.12;
        receptors[normalized].offset.set(2, 2);
        EventBus.publish("strumline/confirm", {lane: normalized});
    }

    public function addNote(note:Note):Note {
        if (note != null && !activeNotes.members.contains(note)) activeNotes.add(note);
        return note;
    }

    public function removeNote(note:Note):Void {
        if (note != null) activeNotes.remove(note, true);
    }

    public function setDownscroll(value:Bool):Void {
        downscroll = value;
        receptorY = value ? FlxG.height * 0.78 : FlxG.height * 0.22;
        for (receptor in receptors) receptor.y = receptorY;
    }

    private function setAnimation(lane:Int, name:String):Void {
        var normalized:Int = normalizeLane(lane);
        receptors[normalized].animation.play(name);
        receptors[normalized].offset.set(name == "confirm" ? 2 : 0, name == "confirm" ? 2 : 0);
    }

    private static function normalizeLane(lane:Int):Int {
        var value:Int = lane % 4;
        return value < 0 ? value + 4 : value;
    }
}
