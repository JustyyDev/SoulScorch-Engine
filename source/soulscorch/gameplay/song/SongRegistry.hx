package soulscorch.gameplay.song;

import flixel.util.FlxColor;
import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef RegisteredSong = {
    var id:String;
    var title:String;
    var bpm:Float;
    var speed:Float;
    var character:String;
    var color:FlxColor;
    var ?difficulties:Array<String>;
    var ?folder:String;
}

class SongRegistry {
    public static var songs:Array<RegisteredSong> = [];
    private static var _songMap:Map<String, RegisteredSong> = new Map<String, RegisteredSong>();

    public static function scanAll():Void {
        songs = [];
        _songMap.clear();

        var rawDiscovered:Map<String, RegisteredSong> = new Map<String, RegisteredSong>();
        gatherWeeks(rawDiscovered);
        gatherSongFolders(rawDiscovered);

        var configOrder:Array<String> = [];

        // 1. Read freeplay.xmsoul configuration
        var freeplayXml:Access = XMSoul.parse("config/freeplay");
        if (freeplayXml == null) freeplayXml = XMSoul.parse("data/config/freeplay");

        if (freeplayXml != null) {
            for (songNode in freeplayXml.nodes.song) {
                var songName = XMSoul.getAttr(songNode, "name", "");
                if (songName.length > 0) {
                    var cleanKey = songName.toLowerCase().trim();
                    if (!configOrder.contains(cleanKey)) configOrder.push(cleanKey);
                }
            }
        } else {
            // Fallback to freeplaySonglist.txt
            var listFilePaths = [
                "data/config/freeplaySonglist",
                "data/config/freeplaySongList",
                "assets/preload/data/config/freeplaySonglist.txt"
            ];
            for (cfgPath in listFilePaths) {
                var rawText = AssetResolver.getText(cfgPath);
                if (rawText != null && rawText.trim().length > 0) {
                    for (line in rawText.split("\n")) {
                        var clean = line.trim();
                        if (clean.length > 0 && !clean.startsWith("//") && !clean.startsWith("#")) {
                            var songKey = clean.toLowerCase().trim();
                            if (!configOrder.contains(songKey)) configOrder.push(songKey);
                        }
                    }
                    break;
                }
            }
        }

        // Add configured songs in order
        for (songKey in configOrder) {
            var matchId = findMatchingSongId(songKey, rawDiscovered);
            if (matchId != null) {
                var entry = rawDiscovered.get(matchId);
                if (!_songMap.exists(entry.id)) {
                    _songMap.set(entry.id, entry);
                    songs.push(entry);
                }
            } else {
                var fallbackEntry = buildSongEntryWithMeta(songKey);
                _songMap.set(fallbackEntry.id, fallbackEntry);
                songs.push(fallbackEntry);
            }
        }

        // Add remaining discovered songs
        for (key in rawDiscovered.keys()) {
            if (!_songMap.exists(key)) {
                _songMap.set(key, rawDiscovered.get(key));
                songs.push(rawDiscovered.get(key));
            }
        }

        if (songs.length == 0) {
            songs.push(buildSongEntryWithMeta("tutorial"));
        }
    }

    private static function findMatchingSongId(query:String, map:Map<String, RegisteredSong>):Null<String> {
        var cleanQ = query.toLowerCase().replace(" ", "").replace("-", "");
        for (key in map.keys()) {
            var cleanKey = key.toLowerCase().replace(" ", "").replace("-", "");
            if (cleanKey == cleanQ) return key;
        }
        return null;
    }

    private static function gatherWeeks(map:Map<String, RegisteredSong>):Void {
        #if sys
        var weekDirs = [
            "data/weeks",
            "assets/preload/data/weeks",
            "assets/data/weeks"
        ];

        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) {
                weekDirs.unshift('mods/$m/data/weeks');
                weekDirs.unshift('mods/$m/weeks');
            }
        }

        for (dir in weekDirs) {
            if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
                for (file in FileSystem.readDirectory(dir)) {
                    var fullPath = '$dir/$file';
                    if (FileSystem.isDirectory(fullPath)) continue;

                    if (file.endsWith(".xmsoul") || file.endsWith(".xml")) {
                        try {
                            var access = new Access(Xml.parse(File.getContent(fullPath)).firstElement());
                            var chars = access.has.characters ? access.att.characters.split(",") : (access.has.chars ? access.att.chars.split(",") : ["dad"]);
                            var charIcon = (chars.length > 0 && chars[0] != "none") ? chars[0].trim() : "face";

                            // Check for <songs><song name="X" /></songs> or direct <song>X</song>
                            if (access.hasNode.songs) {
                                for (s in access.node.songs.nodes.song) {
                                    var songName = XMSoul.getAttr(s, "name", s.innerData.trim());
                                    var cleanId = songName.toLowerCase().trim();
                                    if (cleanId.length > 0 && !map.exists(cleanId)) {
                                        map.set(cleanId, buildSongEntryWithMeta(cleanId, songName, charIcon));
                                    }
                                }
                            } else {
                                for (s in access.nodes.song) {
                                    var songName = XMSoul.getAttr(s, "name", s.innerData.trim());
                                    var cleanId = songName.toLowerCase().trim();
                                    if (cleanId.length > 0 && !map.exists(cleanId)) {
                                        map.set(cleanId, buildSongEntryWithMeta(cleanId, songName, charIcon));
                                    }
                                }
                            }
                        } catch (e:Dynamic) {}
                    } else if (file.endsWith(".json")) {
                        try {
                            var data:Dynamic = Json.parse(File.getContent(fullPath));
                            var songList:Array<Dynamic> = data.songs != null ? cast data.songs : [];
                            var chars:Array<Dynamic> = data.characters != null ? cast data.characters : ["dad"];
                            var charIcon = (chars.length > 0) ? Std.string(chars[0]) : "face";

                            for (s in songList) {
                                var songName = Std.isOfType(s, String) ? Std.string(s) : Std.string(Reflect.field(s, "name"));
                                var cleanId = songName.toLowerCase().trim();
                                if (cleanId.length > 0 && !map.exists(cleanId)) {
                                    map.set(cleanId, buildSongEntryWithMeta(cleanId, songName, charIcon));
                                }
                            }
                        } catch (e:Dynamic) {}
                    }
                }
            }
        }
        #end
    }

    private static function gatherSongFolders(map:Map<String, RegisteredSong>):Void {
        #if sys
        var searchRoots = ["songs", "assets/preload/songs", "assets/songs"];

        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) {
                searchRoots.unshift('mods/$m/songs');
            }
        }

        for (root in searchRoots) {
            if (FileSystem.exists(root) && FileSystem.isDirectory(root)) {
                for (folder in FileSystem.readDirectory(root)) {
                    var fullP = '$root/$folder';
                    if (FileSystem.isDirectory(fullP)) {
                        var cleanId = folder.toLowerCase().trim();
                        if (!map.exists(cleanId)) {
                            map.set(cleanId, buildSongEntryWithMeta(cleanId));
                        }
                    }
                }
            }
        }
        #end
    }

    public static function buildSongEntryWithMeta(id:String, ?defaultTitle:String, ?defaultIcon:String):RegisteredSong {
        var clean = id.toLowerCase().trim();
        var songTitle = defaultTitle != null ? formatSongTitle(defaultTitle) : formatSongTitle(clean);
        var iconChar = defaultIcon != null ? defaultIcon : getDefaultIcon(clean);
        var bpmVal = 100.0;
        var speedVal = 2.0;
        var songColor = getCharColor(iconChar);

        // 1. Check meta.xmsoul
        var metaXml:Access = XMSoul.parse('songs/$clean/meta');
        if (metaXml == null) metaXml = XMSoul.parse('data/$clean/meta');

        if (metaXml != null) {
            songTitle = XMSoul.getAttr(metaXml, "displayName", XMSoul.getAttr(metaXml, "title", songTitle));
            bpmVal = XMSoul.getFloatAttr(metaXml, "bpm", 100.0);
            iconChar = XMSoul.getAttr(metaXml, "icon", iconChar);
            if (metaXml.has.color) {
                var c = FlxColor.fromString(metaXml.att.color);
                if (c != null) songColor = c;
            }
        } else {
            // Fallback: meta.json
            var metaPaths = [
                'songs/$clean/meta.json',
                'data/$clean/meta.json',
                'assets/preload/songs/$clean/meta.json'
            ];
            for (path in metaPaths) {
                var resolved = AssetResolver.resolveFile(path, [".json", ""]);
                if (resolved != null) {
                    var content = AssetResolver.getText(resolved);
                    if (content != null && content.length > 0) {
                        try {
                            var meta:Dynamic = Json.parse(content);
                            if (Reflect.hasField(meta, "displayName")) songTitle = Std.string(Reflect.field(meta, "displayName"));
                            else if (Reflect.hasField(meta, "title")) songTitle = Std.string(Reflect.field(meta, "title"));

                            if (Reflect.hasField(meta, "bpm")) bpmVal = Std.parseFloat(Reflect.field(meta, "bpm"));
                            if (Reflect.hasField(meta, "icon")) iconChar = Std.string(Reflect.field(meta, "icon"));

                            if (Reflect.hasField(meta, "color")) {
                                var c = FlxColor.fromString(Std.string(Reflect.field(meta, "color")));
                                if (c != null) songColor = c;
                            }
                            break;
                        } catch (e:Dynamic) {}
                    }
                }
            }
        }

        // 2. Read chart metadata for BPM/speed if not provided in meta
        if (bpmVal == 100.0) {
            var chartMeta = readSongChartMeta(clean);
            if (chartMeta.bpm > 0) bpmVal = chartMeta.bpm;
            speedVal = chartMeta.speed;
        }

        return {
            id: clean,
            title: songTitle,
            bpm: bpmVal,
            speed: speedVal,
            character: iconChar,
            color: songColor,
            difficulties: ["easy", "normal", "hard"]
        };
    }

    public static function readSongChartMeta(songId:String):{bpm:Float, speed:Float} {
        var cleanSong = songId.toLowerCase().trim();

        // 1. Try reading .xmsoul chart
        var chartXml:Access = XMSoul.parse('songs/$cleanSong/charts/normal');
        if (chartXml == null) chartXml = XMSoul.parse('songs/$cleanSong/charts/hard');
        if (chartXml != null) {
            var speedVal = XMSoul.getFloatAttr(chartXml, "speed", 2.0);
            return {bpm: 100.0, speed: speedVal};
        }

        // 2. Fallback: JSON chart
        var possibleChartPaths = [
            'songs/$cleanSong/charts/normal.json',
            'songs/$cleanSong/charts/hard.json',
            'songs/$cleanSong/chart.json',
            'songs/$cleanSong/$cleanSong.json',
            'data/$cleanSong/$cleanSong.json'
        ];

        for (path in possibleChartPaths) {
            var resolved = AssetResolver.resolveFile(path, [".json", ""]);
            if (resolved != null) {
                var content = AssetResolver.getText(resolved);
                if (content != null && content.length > 0) {
                    try {
                        var parsed:Dynamic = Json.parse(content);
                        var sObj:Dynamic = Reflect.hasField(parsed, "song") ? Reflect.field(parsed, "song") : parsed;
                        var bpmVal:Float = Reflect.hasField(sObj, "bpm") ? Std.parseFloat(Reflect.field(sObj, "bpm")) : 100.0;
                        var speedVal:Float = Reflect.hasField(sObj, "speed") ? Std.parseFloat(Reflect.field(sObj, "speed")) : (Reflect.hasField(sObj, "scrollSpeed") ? Std.parseFloat(Reflect.field(sObj, "scrollSpeed")) : 2.0);
                        return {bpm: bpmVal, speed: speedVal};
                    } catch (e:Dynamic) {}
                }
            }
        }
        return {bpm: 100.0, speed: 2.0};
    }

    private static function getDefaultIcon(song:String):String {
        return switch (song) {
            case "tutorial": "gf";
            case "bopeebo", "fresh", "dadbattle", "dad-battle": "dad";
            case "spookeez", "south", "monster": "spooky";
            case "pico", "philly", "philly-nice", "blammed": "pico";
            case "satin-panties", "high", "milf": "mom";
            case "cocoa", "eggnog", "winter-horrorland": "parents-christmas";
            case "senpai", "roses", "thorns": "senpai";
            case "ugh", "guns", "stress": "tankman";
            default: "face";
        };
    }

    private static function formatSongTitle(raw:String):String {
        var clean = raw.trim();
        if (clean.toLowerCase() == "dadbattle") return "Dad Battle";
        if (clean.toLowerCase() == "phillynice") return "Philly Nice";
        if (clean.toLowerCase() == "satinpanties") return "Satin Panties";
        if (clean.toLowerCase() == "winterhorrorland") return "Winter Horrorland";
        return clean.replace("-", " ").replace("_", " ");
    }

    public static function getCharColor(char:String):FlxColor {
        return switch (char.toLowerCase()) {
            case "dad": 0xFFAF66CE;
            case "spooky": 0xFFD57E00;
            case "pico": 0xFFB7D855;
            case "mom", "mom-car": 0xFFD8558E;
            case "parents-christmas": 0xFF7645B8;
            case "senpai", "senpai-angry": 0xFFFFAA6F;
            case "spirit": 0xFFFF3C1F;
            case "tankman": 0xFF000000;
            case "monster": 0xFFF3FF6E;
            case "gf": 0xFFA5004D;
            default: 0xFF282035;
        };
    }
}