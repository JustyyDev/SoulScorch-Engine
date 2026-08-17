package soulscorch.gameplay.notes;

import haxe.Json;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.Chart;
import soulscorch.scripting.ModLoader;

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
        if (rawJson == null || rawJson.length == 0) {
            return null;
        }

        var root:Dynamic = Json.parse(rawJson);
        var song:Dynamic = Reflect.hasField(root, "song") ? Reflect.field(root, "song") : root;

        var bpm:Float = numberField(song, "bpm", 120.0);[cite: 72]
        var speed:Float = numberField(song, "speed", numberField(song, "scrollSpeed", 1.0));[cite: 72]
        var chart:Chart = new Chart(bpm, speed);[cite: 72]
        var sections:Array<ParsedSection> = [];[cite: 72]
        var events:Array<Dynamic> = [];[cite: 72]

        var sectionArray:Dynamic = field(song, "notes");[cite: 72]
        if (sectionArray == null) sectionArray = field(song, "sections");[cite: 72]

        if (sectionArray != null && Std.isOfType(sectionArray, Array)) {
            var index:Int = 0;
            var curBpmCalc:Float = bpm;

            for (rawSection in (cast sectionArray : Array<Dynamic>)) {
                if (rawSection == null) continue;

                if (rawSection.changeBPM == true && rawSection.bpm != null) {
                    curBpmCalc = rawSection.bpm;
                }

                var mustHit:Bool = boolField(rawSection, "mustHitSection", boolField(rawSection, "mustHit", true));[cite: 72]
                var sectionNotes:Array<Note> = [];[cite: 72]
                var noteArray:Dynamic = field(rawSection, "sectionNotes");[cite: 72]
                if (noteArray == null) noteArray = field(rawSection, "notes");[cite: 72]

                if (noteArray != null && Std.isOfType(noteArray, Array)) {
                    for (rawNote in (cast noteArray : Array<Dynamic>)) {
                        var parsed:Note = parseNote(rawNote, mustHit);[cite: 72]
                        if (parsed != null) {
                            chart.addNote(parsed.strumTime, parsed.noteData, parsed.sustainLength, parsed.noteType, parsed.mustPress);
                            sectionNotes.push(parsed);

                            // Construct sustain hold trail and end pieces
                            if (parsed.sustainLength > 0) {
                                var stepCrochet:Float = ((60.0 / curBpmCalc) * 1000.0) / 4.0;
                                var holdLength:Float = parsed.sustainLength;
                                var holdSteps:Int = Math.floor(holdLength / stepCrochet);

                                for (s in 0...holdSteps) {
                                    var isEnd:Bool = (s == holdSteps - 1);
                                    var susTime:Float = parsed.strumTime + (s * stepCrochet) + stepCrochet;
                                    var sustainNode = new Note(
                                        susTime,
                                        parsed.noteData,
                                        holdLength,
                                        parsed,
                                        true,
                                        isEnd,
                                        parsed.mustPress,
                                        parsed.noteType
                                    );
                                    parsed.tail.push(sustainNode);
                                }
                            }
                        }
                    }
                }

                var sectionEvents:Dynamic = field(rawSection, "events");[cite: 72]
                if (sectionEvents != null && Std.isOfType(sectionEvents, Array)) {
                    for (event in (cast sectionEvents : Array<Dynamic>)) events.push(event);[cite: 72]
                }

                sections.push({
                    startTime: numberField(rawSection, "startTime", index * 2000.0),[cite: 72]
                    mustHitSection: mustHit,[cite: 72]
                    notes: sectionNotes,[cite: 72]
                    events: sectionEvents == null ? [] : cast sectionEvents[cite: 72]
                });
                index++;
            }
        }

        var rootEvents:Dynamic = field(song, "events");[cite: 72]
        if (rootEvents != null && Std.isOfType(rootEvents, Array)) {
            for (event in (cast rootEvents : Array<Dynamic>)) events.push(event);[cite: 72]
        }

        return {
            songId: songId,
            songName: stringField(song, "song", songId),[cite: 72]
            bpm: bpm,
            speed: speed,
            chart: chart,
            sections: sections,
            events: events
        };
    }

    public static function load(songId:String, difficulty:String = "normal"):Null<ParsedSong> {
        var diff = difficulty.toLowerCase().trim();
        var diffSuffix = (diff == "normal") ? "" : '-$diff';

        var possiblePaths = [
            'assets/songs/$songId/charts/$diff.json',
            'assets/songs/$songId/chart$diffSuffix.json',
            'assets/songs/$songId/$songId$diffSuffix.json',
            'assets/songs/$songId/chart.json'
        ];

        for (path in possiblePaths) {
            var resolved = ModLoader.getPath(path);
            if (AssetResolver.exists(resolved)) {
                return parse(AssetResolver.getText(resolved), songId);
            }
        }

        Logger.warn('Failed to locate chart file for: $songId ($difficulty)', "parser");
        return null;
    }

    private static function parseNote(raw:Dynamic, mustHit:Bool):Null<Note> {
        if (raw == null) return null;[cite: 72]

        if (Std.isOfType(raw, Array)) {
            var values:Array<Dynamic> = cast raw;
            if (values.length < 2) return null;[cite: 72]
            var lane:Int = Std.int(numberValue(values[1], 0));[cite: 72]
            var player:Bool = (lane >= 4) ? !mustHit : mustHit;[cite: 72]
            var type:String = (values.length > 3) ? Std.string(values[3]) : "Default";

            return new Note(
                numberValue(values[0], 0),[cite: 72]
                lane % 4,[cite: 72]
                values.length > 2 ? numberValue(values[2], 0) : 0,[cite: 72]
                null,
                false,
                false,
                player,
                type
            );
        }

        var laneValue:Int = Std.int(numberField(raw, "noteData", numberField(raw, "direction", 0)));[cite: 72]
        return new Note(
            numberField(raw, "strumTime", numberField(raw, "time", 0)),[cite: 72]
            laneValue % 4,[cite: 72]
            numberField(raw, "sustainLength", 0),[cite: 72]
            null,
            false,
            false,
            boolField(raw, "mustPress", mustHit),[cite: 72]
            stringField(raw, "noteType", "Default")[cite: 72]
        );
    }

    private static inline function field(value:Dynamic, name:String):Dynamic {
        return (value != null && Reflect.hasField(value, name)) ? Reflect.field(value, name) : null;[cite: 72]
    }

    private static inline function numberField(value:Dynamic, name:String, fallback:Float):Float {
        return numberValue(field(value, name), fallback);[cite: 72]
    }

    private static inline function numberValue(value:Dynamic, fallback:Float):Float {
        return (value == null) ? fallback : (Std.isOfType(value, Float) || Std.isOfType(value, Int) ? cast value : fallback);[cite: 72]
    }

    private static inline function boolField(value:Dynamic, name:String, fallback:Bool):Bool {
        var found:Dynamic = field(value, name);[cite: 72]
        return (found == null) ? fallback : cast found;[cite: 72]
    }

    private static inline function stringField(value:Dynamic, name:String, fallback:String):String {
        var found:Dynamic = field(value, name);[cite: 72]
        return (found == null) ? fallback : Std.string(found);[cite: 72]
    }
}