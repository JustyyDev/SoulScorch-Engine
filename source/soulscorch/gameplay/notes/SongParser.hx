package soulscorch.gameplay.notes;

import haxe.Json;
import soulscorch.gameplay.Chart;
import soulscorch.modding.ModManager;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef ParsedSection = {
    var startTime:Float;
    var mustHitSection:Bool;
    var notes:Array<Note>;
    var events:Array<Dynamic>;
}

typedef ParsedSong = {
    var songId:String;
    var songName:String;
    var bpm:Float;
    var speed:Float;
    var chart:Chart;
    var sections:Array<ParsedSection>;
    var events:Array<Dynamic>;
}

class SongParser {
    public static function parse(rawJson:String, ?songId:String = "song"):ParsedSong {
        var root:Dynamic = Json.parse(rawJson);
        var song:Dynamic = Reflect.hasField(root, "song") ? Reflect.field(root, "song") : root;
        var bpm:Float = numberField(song, "bpm", 120.0);
        var speed:Float = numberField(song, "speed", numberField(song, "scrollSpeed", 1.0));
        var chart:Chart = new Chart(bpm, speed);
        var sections:Array<ParsedSection> = [];
        var events:Array<Dynamic> = [];
        var sectionArray:Dynamic = field(song, "notes");
        if (sectionArray == null) sectionArray = field(song, "sections");
        if (sectionArray != null && Std.isOfType(sectionArray, Array)) {
            var index:Int = 0;
            for (rawSection in (cast sectionArray:Array<Dynamic>)) {
                var mustHit:Bool = boolField(rawSection, "mustHitSection", boolField(rawSection, "mustHit", true));
                var sectionNotes:Array<Note> = [];
                var noteArray:Dynamic = field(rawSection, "sectionNotes");
                if (noteArray == null) noteArray = field(rawSection, "notes");
                if (noteArray != null && Std.isOfType(noteArray, Array)) {
                    for (rawNote in (cast noteArray:Array<Dynamic>)) {
                        var parsed:Note = parseNote(rawNote, mustHit);
                        if (parsed != null) {
                            chart.addNote(parsed.strumTime, parsed.noteData, parsed.sustainLength, parsed.noteType, parsed.mustPress);
                            sectionNotes.push(parsed);
                        }
                    }
                }
                var sectionEvents:Dynamic = field(rawSection, "events");
                if (sectionEvents != null && Std.isOfType(sectionEvents, Array)) for (event in (cast sectionEvents:Array<Dynamic>)) events.push(event);
                sections.push({startTime: numberField(rawSection, "startTime", index * 2000.0), mustHitSection: mustHit, notes: sectionNotes, events: sectionEvents == null ? [] : cast sectionEvents});
                index++;
            }
        }
        var rootEvents:Dynamic = field(song, "events");
        if (rootEvents != null && Std.isOfType(rootEvents, Array)) for (event in (cast rootEvents:Array<Dynamic>)) events.push(event);
        return {songId: songId, songName: stringField(song, "song", songId), bpm: bpm, speed: speed, chart: chart, sections: sections, events: events};
    }

    public static function load(songId:String, difficulty:String = "normal"):Null<ParsedSong> {
        var path:String = ModManager.getPath('data/songs/$songId/$songId-$difficulty.json');
        #if sys
        if (path != null && FileSystem.exists(path)) return parse(File.getContent(path), songId);
        #end
        return null;
    }

    private static function parseNote(raw:Dynamic, mustHit:Bool):Null<Note> {
        if (raw == null) return null;
        if (Std.isOfType(raw, Array)) {
            var values:Array<Dynamic> = cast raw;
            if (values.length < 2) return null;
            var lane:Int = Std.int(numberValue(values[1], 0));
            var player:Bool = lane >= 4 ? !mustHit : mustHit;
            return new Note(numberValue(values[0], 0), lane % 4, values.length > 2 ? numberValue(values[2], 0) : 0, null, false, player);
        }
        var laneValue:Int = Std.int(numberField(raw, "noteData", numberField(raw, "direction", 0)));
        return new Note(numberField(raw, "strumTime", numberField(raw, "time", 0)), laneValue % 4, numberField(raw, "sustainLength", 0), null, false, boolField(raw, "mustPress", mustHit), stringField(raw, "noteType", "Default"));
    }

    private static function field(value:Dynamic, name:String):Dynamic return value != null && Reflect.hasField(value, name) ? Reflect.field(value, name) : null;
    private static function numberField(value:Dynamic, name:String, fallback:Float):Float return numberValue(field(value, name), fallback);
    private static function numberValue(value:Dynamic, fallback:Float):Float return value == null ? fallback : (Std.isOfType(value, Float) || Std.isOfType(value, Int) ? cast value : fallback);
    private static function boolField(value:Dynamic, name:String, fallback:Bool):Bool { var found:Dynamic = field(value, name); return found == null ? fallback : cast found; }
    private static function stringField(value:Dynamic, name:String, fallback:String):String { var found:Dynamic = field(value, name); return found == null ? fallback : Std.string(found); }
}
