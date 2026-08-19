package soulscorch.gameplay.notes;

import haxe.Json;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.Chart;

using StringTools;

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
    public static function parse(rawJson:String, ?songId:String = "song"):Null<ParsedSong> {
        if (rawJson == null || rawJson.trim().length == 0) return null;

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
            var curBpmCalc:Float = bpm;

            for (rawSection in (cast sectionArray : Array<Dynamic>)) {
                if (rawSection == null) continue;

                if (rawSection.changeBPM == true && rawSection.bpm != null) {
                    curBpmCalc = rawSection.bpm;
                }

                var mustHit:Bool = boolField(rawSection, "mustHitSection", boolField(rawSection, "mustHit", true));
                var sectionNotes:Array<Note> = [];
                var noteArray:Dynamic = field(rawSection, "sectionNotes");
                if (noteArray == null) noteArray = field(rawSection, "notes");

                if (noteArray != null && Std.isOfType(noteArray, Array)) {
                    for (rawNote in (cast noteArray : Array<Dynamic>)) {
                        var parsed:Note = parseNote(rawNote, mustHit);
                        if (parsed != null) {
                            chart.addNote(parsed.strumTime, parsed.noteData, parsed.sustainLength, parsed.noteType, parsed.mustPress);
                            sectionNotes.push(parsed);

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

                var sectionEvents:Dynamic = field(rawSection, "events");
                if (sectionEvents != null && Std.isOfType(sectionEvents, Array)) {
                    for (event in (cast sectionEvents : Array<Dynamic>)) events.push(event);
                }

                sections.push({
                    startTime: numberField(rawSection, "startTime", index * 2000.0),
                    mustHitSection: mustHit,
                    notes: sectionNotes,
                    events: sectionEvents == null ? [] : cast sectionEvents
                });
                index++;
            }
        }

        var rootEvents:Dynamic = field(song, "events");
        if (rootEvents != null && Std.isOfType(rootEvents, Array)) {
            for (event in (cast rootEvents : Array<Dynamic>)) events.push(event);
        }

        var result:ParsedSong = {
            songId: songId,
            songName: stringField(song, "song", songId),
            bpm: bpm,
            speed: speed,
            chart: chart,
            sections: sections,
            events: events
        };

        return result;
    }

    public static function load(songId:String, ?difficulty:String = "normal"):Null<ParsedSong> {
        var cleanSong = (songId != null && songId.trim().length > 0) ? songId.toLowerCase().trim() : "tutorial";
        var diff = (difficulty != null && difficulty.trim().length > 0) ? difficulty.toLowerCase().trim() : "normal";
        var diffSuffix = (diff == "normal") ? "" : '-$diff';

        var possiblePaths = [
            'songs/$cleanSong/charts/$diff.json',
            'songs/$cleanSong/chart$diffSuffix.json',
            'songs/$cleanSong/$cleanSong$diffSuffix.json',
            'songs/$cleanSong/chart.json',
            'data/$cleanSong/$cleanSong$diffSuffix.json',
            'data/$cleanSong/chart$diffSuffix.json',
            'assets/preload/songs/$cleanSong/charts/$diff.json',
            'assets/preload/songs/$cleanSong/charts/$cleanSong$diffSuffix.json'
        ];

        for (path in possiblePaths) {
            var resolved = AssetResolver.resolveFile(path, [".json", ""]);
            if (resolved != null) {
                var content = AssetResolver.getText(resolved);
                if (content != null && content.trim().length > 0) {
                    return parse(content, cleanSong);
                }
            }
        }

        Logger.warn('Failed to locate chart file for: $cleanSong ($diff)', "parser");
        return null;
    }

    private static function parseNote(raw:Dynamic, mustHit:Bool):Null<Note> {
        if (raw == null) return null;

        if (Std.isOfType(raw, Array)) {
            var values:Array<Dynamic> = cast raw;
            if (values.length < 2) return null;
            var lane:Int = Std.int(numberValue(values[1], 0));
            var player:Bool = (lane >= 4) ? !mustHit : mustHit;
            var type:String = (values.length > 3 && values[3] != null) ? Std.string(values[3]) : "default";

            return new Note(
                numberValue(values[0], 0),
                lane % 4,
                values.length > 2 ? numberValue(values[2], 0) : 0,
                null,
                false,
                false,
                player,
                type
            );
        }

        var laneValue:Int = Std.int(numberField(raw, "noteData", numberField(raw, "direction", 0)));
        return new Note(
            numberField(raw, "strumTime", numberField(raw, "time", 0)),
            laneValue % 4,
            numberField(raw, "sustainLength", 0),
            null,
            false,
            false,
            boolField(raw, "mustPress", mustHit),
            stringField(raw, "noteType", "default")
        );
    }

    private static inline function field(value:Dynamic, name:String):Dynamic {
        return (value != null && Reflect.hasField(value, name)) ? Reflect.field(value, name) : null;
    }

    private static inline function numberField(value:Dynamic, name:String, fallback:Float):Float {
        return numberValue(field(value, name), fallback);
    }

    private static inline function numberValue(value:Dynamic, fallback:Float):Float {
        return (value == null) ? fallback : (Std.isOfType(value, Float) || Std.isOfType(value, Int) ? cast value : fallback);
    }

    private static inline function boolField(value:Dynamic, name:String, fallback:Bool):Bool {
        var found:Dynamic = field(value, name);
        return (found == null) ? fallback : cast found;
    }

    private static inline function stringField(value:Dynamic, name:String, fallback:String):String {
        var found:Dynamic = field(value, name);
        return (found == null) ? fallback : Std.string(found);
    }
}