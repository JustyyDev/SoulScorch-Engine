package soulscorch.gameplay.chart;

import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.Song;

using StringTools;

class ChartParser {
    public static function parse(rawContent:String, ?songId:String = "song"):Null<Song> {
        if (rawContent == null || rawContent.trim().length == 0) return null;

        var clean = rawContent.trim();

        // 1. Parse XML / .soulchart / .xmsoul Formats
        if (clean.startsWith("<")) {
            return parseXmlChart(clean, songId);
        }

        // 2. Parse JSON Formats (Codename, Psych, Legacy FNF)
        return parseJsonChart(clean, songId);
    }

    private static function parseXmlChart(xmlString:String, songId:String):Null<Song> {
        try {
            var xml = Xml.parse(xmlString);
            var access = new Access(xml.firstElement());

            var speed = XMSoul.getFloatAttr(access, "speed", 2.0);
            var bpm = XMSoul.getFloatAttr(access, "bpm", 100.0);
            var player1 = XMSoul.getAttr(access, "player1", "bf");
            var player2 = XMSoul.getAttr(access, "player2", "dad");
            var gf = XMSoul.getAttr(access, "gfVersion", "gf");
            var stage = XMSoul.getAttr(access, "stage", "stage");

            var songInstance = new Song(songId, songId);
            songInstance.bpm = bpm;
            songInstance.scrollSpeed = speed;
            songInstance.player1 = player1;
            songInstance.player2 = player2;
            songInstance.gfVersion = gf;
            songInstance.stage = stage;

            var chart = new Chart(bpm, speed);

            for (strumLine in access.nodes.resolve("strumLine")) {
                var lineType = XMSoul.getAttr(strumLine, "type", "opponent").toLowerCase();
                var isVisible = XMSoul.getBoolAttr(strumLine, "visible", true);
                if (!isVisible || lineType == "ambient") continue;

                var isPlayer = lineType == "player"
                    || XMSoul.getAttr(strumLine, "position", "").toLowerCase() == "boyfriend";

                for (noteNode in strumLine.nodes.resolve("note")) {
                    var t = XMSoul.getFloatAttr(noteNode, "time", 0.0);
                    var lane = XMSoul.getIntAttr(noteNode, "lane", XMSoul.getIntAttr(noteNode, "id", 0));
                    var len = XMSoul.getFloatAttr(noteNode, "len", XMSoul.getFloatAttr(noteNode, "sLen", 0.0));
                    var type = XMSoul.getAttr(noteNode, "type", "normal");
                    var alt = XMSoul.getBoolAttr(noteNode, "alt", false);

                    chart.addNote(t, lane % 4, len, type, isPlayer, alt);
                }
            }

            if (access.hasNode.resolve("events")) {
                for (ev in access.node.resolve("events").nodes.resolve("event")) {
                    var evTime = XMSoul.getFloatAttr(ev, "time", 0.0);
                    var evName = XMSoul.getAttr(ev, "name", "");
                    var val1 = XMSoul.getAttr(ev, "val1", XMSoul.getAttr(ev, "target", ""));
                    var val2 = XMSoul.getAttr(ev, "val2", XMSoul.getAttr(ev, "anim", ""));
                    chart.addEvent(evTime, evName, val1, val2);
                }
            }

            chart.sortNotes();
            chart.sortEvents();
            songInstance.chart = chart;
            return songInstance;
        } catch (e:Dynamic) {
            Logger.error('Failed parsing XML chart for $songId: $e', "chart");
            return null;
        }
    }

    private static function parseJsonChart(jsonString:String, songId:String):Null<Song> {
        try {
            var root:Dynamic = Json.parse(jsonString);
            var songObj:Dynamic = Reflect.hasField(root, "song") ? Reflect.field(root, "song") : root;

            var songName:String = Reflect.hasField(songObj, "song") ? Std.string(Reflect.field(songObj, "song")) : songId;
            var bpmVal:Float = Reflect.hasField(songObj, "bpm") ? Std.parseFloat(Std.string(Reflect.field(songObj, "bpm"))) : 120.0;
            var speedVal:Float = Reflect.hasField(songObj, "speed") ? Std.parseFloat(Std.string(Reflect.field(songObj, "speed"))) : (Reflect.hasField(root, "scrollSpeed") ? Std.parseFloat(Std.string(Reflect.field(root, "scrollSpeed"))) : 2.0);
            var player1:String = Reflect.hasField(songObj, "player1") ? Std.string(Reflect.field(songObj, "player1")) : "bf";
            var player2:String = Reflect.hasField(songObj, "player2") ? Std.string(Reflect.field(songObj, "player2")) : "dad";
            var gfVersion:String = Reflect.hasField(songObj, "gfVersion") ? Std.string(Reflect.field(songObj, "gfVersion")) : "gf";
            var stage:String = Reflect.hasField(songObj, "stage") ? Std.string(Reflect.field(songObj, "stage")) : "stage";
            var needsVoices:Bool = Reflect.hasField(songObj, "needsVoices") ? Reflect.field(songObj, "needsVoices") == true : true;

            var songInstance = new Song(songId, songName);
            songInstance.bpm = bpmVal;
            songInstance.scrollSpeed = speedVal;
            songInstance.player1 = player1;
            songInstance.player2 = player2;
            songInstance.gfVersion = gfVersion;
            songInstance.stage = stage;
            songInstance.needsVoices = needsVoices;

            var chart = new Chart(bpmVal, speedVal);

            // A. Codename Engine Format ("strumLines")
            if (Reflect.hasField(root, "strumLines") || Reflect.hasField(songObj, "strumLines")) {
                var sLines:Array<Dynamic> = Reflect.hasField(root, "strumLines") ? Reflect.field(root, "strumLines") : Reflect.field(songObj, "strumLines");
                for (sLine in sLines) {
                    var isPlayer = (sLine.position == "boyfriend" || sLine.type == 1 || sLine.type == "player");
                    if (sLine.notes != null && Std.isOfType(sLine.notes, Array)) {
                        for (rawNote in (cast sLine.notes : Array<Dynamic>)) {
                            var t:Float = rawNote.time != null ? rawNote.time : 0.0;
                            var lane:Int = rawNote.id != null ? rawNote.id : (rawNote.lane != null ? rawNote.lane : 0);
                            var sLen:Float = rawNote.sLen != null ? rawNote.sLen : (rawNote.length != null ? rawNote.length : 0.0);
                            var type:String = rawNote.type != null ? Std.string(rawNote.type) : "normal";

                            chart.addNote(t, lane % 4, sLen, type, isPlayer);
                        }
                    }
                }

                if (Reflect.hasField(root, "events") && Std.isOfType(Reflect.field(root, "events"), Array)) {
                    for (ev in (cast Reflect.field(root, "events") : Array<Dynamic>)) {
                        var evTime:Float = ev.time != null ? ev.time : 0.0;
                        var evName:String = ev.name != null ? Std.string(ev.name) : Std.string(ev.type);
                        var params:Array<Dynamic> = ev.params != null ? cast ev.params : [];
                        chart.addEvent(evTime, evName, params.length > 0 ? params[0] : "", params.length > 1 ? params[1] : "");
                    }
                }
            }
            // B. Base Game & Psych Format ("notes" / "sections")
            else {
                var sections:Array<Dynamic> = Reflect.hasField(songObj, "notes") ? Reflect.field(songObj, "notes") : (Reflect.hasField(songObj, "sections") ? Reflect.field(songObj, "sections") : []);

                for (section in sections) {
                    if (section == null) continue;
                    var mustHit:Bool = Reflect.hasField(section, "mustHitSection") ? Reflect.field(section, "mustHitSection") == true : true;
                    var altAnim:Bool = Reflect.hasField(section, "altAnim") ? Reflect.field(section, "altAnim") == true : false;
                    var sectionNotes:Array<Dynamic> = Reflect.hasField(section, "sectionNotes") ? Reflect.field(section, "sectionNotes") : [];

                    for (rawNote in sectionNotes) {
                        if (rawNote != null && Std.isOfType(rawNote, Array)) {
                            var arr:Array<Dynamic> = cast rawNote;
                            var strumTime:Float = arr[0];
                            var noteData:Int = Std.int(arr[1]);
                            var sustainLength:Float = (arr.length > 2) ? arr[2] : 0.0;
                            var noteType:String = (arr.length > 3 && arr[3] != null) ? Std.string(arr[3]) : "normal";

                            var isPlayerNote:Bool = (noteData >= 4) ? !mustHit : mustHit;
                            chart.addNote(strumTime, noteData % 4, sustainLength, noteType, isPlayerNote, altAnim);
                        }
                    }
                }

                if (Reflect.hasField(songObj, "events") && Std.isOfType(Reflect.field(songObj, "events"), Array)) {
                    for (evRow in (cast Reflect.field(songObj, "events") : Array<Dynamic>)) {
                        if (evRow != null && Std.isOfType(evRow, Array) && evRow.length >= 2) {
                            var evTime:Float = evRow[0];
                            var evList:Array<Dynamic> = cast evRow[1];
                            for (singleEv in evList) {
                                if (singleEv != null && Std.isOfType(singleEv, Array) && singleEv.length >= 3) {
                                    chart.addEvent(evTime, Std.string(singleEv[0]), singleEv[1], singleEv[2]);
                                }
                            }
                        }
                    }
                }
            }

            chart.sortNotes();
            chart.sortEvents();
            songInstance.chart = chart;
            return songInstance;
        } catch (e:Dynamic) {
            Logger.error('Failed parsing JSON chart for $songId: $e', "chart");
            return null;
        }
    }
}