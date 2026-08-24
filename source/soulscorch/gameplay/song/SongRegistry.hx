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
    var ?artist:String;
    var ?charter:String;
    var ?difficulties:Array<String>;
    var ?folder:String;
}

class SongRegistry {
    public static var songs:Array<RegisteredSong> = [];
    private static var _songMap:Map<String, RegisteredSong> = new Map<String, RegisteredSong>();

    public static function scanAll():Void {
        songs = [];
        _songMap.clear();

        var freeplayPath:String = null;
        #if sys
        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) {
                var modRoot = ModManager.getModFolderRootPath(m);
                var candidatePaths = [
                    '$modRoot/$m/data/config/freeplay.xmsoul',
                    '$modRoot/$m/config/freeplay.xmsoul',
                    '$modRoot/$m/data/config/freeplayList.xmsoul',
                    '$modRoot/$m/data/freeplay.xmsoul',
                    '$modRoot/$m/freeplay.xmsoul',
                    '$modRoot/$m/data/freeplaySongList.txt'
                ];
                for (p in candidatePaths) {
                    if (FileSystem.exists(p)) {
                        freeplayPath = p;
                        break;
                    }
                }
                if (freeplayPath != null) break;
            }
        }
        #end

        if (freeplayPath == null) {
            var probes = ["config/freeplay", "data/config/freeplay", "data/config/freeplayList", "data/freeplaySongList"];
            for (pr in probes) {
                var res = AssetResolver.resolveFile(pr, [".xmsoul", ".xml", ".txt", ""]);
                if (res != null) {
                    freeplayPath = res;
                    break;
                }
            }
        }

        if (freeplayPath != null) {
            if (freeplayPath.endsWith(".txt")) {
                parseLegacyTextList(freeplayPath);
            } else {
                var freeplayXml:Access = XMSoul.parse(freeplayPath, false);
                if (freeplayXml != null) {
                    for (songNode in freeplayXml.elements) {
                        if (songNode.name.toLowerCase() == "song") {
                            var songId = XMSoul.getAttr(songNode, "id", XMSoul.getAttr(songNode, "name", "")).toLowerCase().trim();
                            if (songId.length == 0) continue;

                            var explicitTitle = XMSoul.getAttr(songNode, "name", formatSongTitle(songId));
                            var explicitIcon = XMSoul.getAttr(songNode, "icon", "");
                            var explicitDiffs = XMSoul.getArrayAttr(songNode, "difficulties", ",");

                            var entry = buildSongEntryWithMeta(songId, explicitTitle, explicitIcon.length > 0 ? explicitIcon : null);

                            if (songNode.has.color) {
                                var parsedCol:Null<FlxColor> = parseColorString(songNode.att.color);
                                if (parsedCol != null) entry.color = parsedCol;
                            }

                            if (explicitDiffs.length > 0) {
                                var available = detectAvailableDifficulties(songId);
                                var validExplicit:Array<String> = [];

                                if (available.length > 0) {
                                    for (d in explicitDiffs) {
                                        var cleanDiff = d.toLowerCase().trim();
                                        if (available.contains(cleanDiff)) validExplicit.push(cleanDiff);
                                    }
                                }

                                entry.difficulties = (validExplicit.length > 0) ? validExplicit : explicitDiffs;
                            }

                            if (!_songMap.exists(entry.id)) {
                                _songMap.set(entry.id, entry);
                                songs.push(entry);
                            }
                        }
                    }
                }
            }
            if (songs.length > 0) return;
        }

        var rawDiscovered:Map<String, RegisteredSong> = new Map<String, RegisteredSong>();
        gatherWeeks(rawDiscovered);
        gatherSongFolders(rawDiscovered);

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

    private static function parseLegacyTextList(path:String):Void {
        #if sys
        var lines = File.getContent(path).split("\n");
        for (line in lines) {
            var parts = line.trim().split(":");
            if (parts.length > 0 && parts[0].trim().length > 0) {
                var sId = parts[0].trim().toLowerCase();
                var sIcon = parts.length > 1 ? parts[1].trim() : getDefaultIcon(sId);
                var entry = buildSongEntryWithMeta(sId, formatSongTitle(sId), sIcon);
                if (!_songMap.exists(entry.id)) {
                    _songMap.set(entry.id, entry);
                    songs.push(entry);
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
        var songColor:FlxColor = getCharColor(iconChar);
        var detectedDiffs:Array<String> = [];
        var artistName:String = "Unknown";
        var charterName:String = "Unknown";

        var metaXml:Access = XMSoul.parse('songs/$clean/meta', false);
        if (metaXml == null) metaXml = XMSoul.parse('data/$clean/meta', false);

        if (metaXml != null) {
            songTitle = XMSoul.getAttr(metaXml, "displayName", XMSoul.getAttr(metaXml, "title", songTitle));
            bpmVal = XMSoul.getFloatAttr(metaXml, "bpm", 100.0);
            iconChar = XMSoul.getAttr(metaXml, "icon", iconChar);
            artistName = XMSoul.getAttr(metaXml, "artist", "Unknown");
            charterName = XMSoul.getAttr(metaXml, "charter", "Unknown");

            if (metaXml.has.color) {
                var c:Null<FlxColor> = parseColorString(metaXml.att.color);
                if (c != null) songColor = c;
            }
            if (metaXml.hasNode.difficulties) {
                var difficultiesNode = metaXml.node.difficulties;
                detectedDiffs = XMSoul.getArrayAttr(difficultiesNode, "names", ",");
                if (detectedDiffs.length == 0) detectedDiffs = XMSoul.getArrayAttr(difficultiesNode, "list", ",");

                if (detectedDiffs.length == 0) {
                    for (difficultyNode in difficultiesNode.nodes.difficulty) {
                        var difficultyName = XMSoul.getAttr(difficultyNode, "name", "").toLowerCase().trim();
                        if (difficultyName.length > 0 && !detectedDiffs.contains(difficultyName)) detectedDiffs.push(difficultyName);
                    }
                }
            }
        } else {
            var metaPaths = [
                'songs/$clean/meta.json',
                'songs/$clean/_meta.json',
                'songs/$clean/metadata.json',
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
                            if (Reflect.hasField(meta, "artist")) artistName = Std.string(Reflect.field(meta, "artist"));
                            if (Reflect.hasField(meta, "charter")) charterName = Std.string(Reflect.field(meta, "charter"));

                            if (Reflect.hasField(meta, "color")) {
                                var c:Null<FlxColor> = parseColorString(Std.string(Reflect.field(meta, "color")));
                                if (c != null) songColor = c;
                            }
                            if (Reflect.hasField(meta, "difficulties")) {
                                detectedDiffs = cast Reflect.field(meta, "difficulties");
                            }
                            break;
                        } catch (e:Dynamic) {}
                    }
                }
            }
        }

        if (detectedDiffs.length == 0) {
            detectedDiffs = detectAvailableDifficulties(clean);
        }

        if (detectedDiffs.length == 0) {
            detectedDiffs = ["easy", "normal", "hard"];
        }

        if (bpmVal == 100.0) {
            var chartMeta = readSongChartMeta(clean, detectedDiffs[0]);
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
            artist: artistName,
            charter: charterName,
            difficulties: detectedDiffs
        };
    }

    public static function detectAvailableDifficulties(songId:String):Array<String> {
        var foundDiffs:Array<String> = [];
        var clean = songId.toLowerCase().trim();

        #if sys
        var searchFolders = [
            'songs/$clean/charts',
            'songs/$clean',
            'data/$clean',
            'assets/preload/songs/$clean/charts',
            'assets/songs/$clean/charts'
        ];

        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) {
                var modRoot = ModManager.getModFolderRootPath(m);
                searchFolders.unshift('$modRoot/$m/songs/$clean/charts');
                searchFolders.unshift('$modRoot/$m/songs/$clean');
                searchFolders.unshift('$modRoot/$m/data/$clean');
            }
        }

        for (folder in searchFolders) {
            if (FileSystem.exists(folder) && FileSystem.isDirectory(folder)) {
                for (file in FileSystem.readDirectory(folder)) {
                    var lower = file.toLowerCase();
                    if (lower.endsWith(".xmsoul") || lower.endsWith(".xml") || lower.endsWith(".json")) {
                        var diffName = file.substr(0, file.lastIndexOf(".")).toLowerCase();
                        if (diffName.startsWith(clean + "-")) diffName = diffName.substr(clean.length + 1);

                        if (diffName != "events" && diffName != "meta" && diffName != "metadata" && diffName != "modifiers" && diffName != "config" && !foundDiffs.contains(diffName)) {
                            foundDiffs.push(diffName);
                        }
                    }
                }
            }
        }
        #end

        return foundDiffs;
    }

    public static function readSongChartMeta(songId:String, ?targetDiff:String = "normal"):{bpm:Float, speed:Float} {
        var cleanSong = songId.toLowerCase().trim();
        var diff = targetDiff.toLowerCase().trim();

        var chartXml:Access = XMSoul.parse('songs/$cleanSong/charts/$diff', false);
        if (chartXml == null) chartXml = XMSoul.parse('songs/$cleanSong/$diff', false);
        if (chartXml != null) {
            var speedVal = XMSoul.getFloatAttr(chartXml, "speed", 2.0);
            return {bpm: 100.0, speed: speedVal};
        }

        var possibleChartPaths = [
            'songs/$cleanSong/charts/$diff.json',
            'songs/$cleanSong/$diff.json',
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

    private static function gatherWeeks(map:Map<String, RegisteredSong>):Void {
        #if sys
        var weekDirs = ["data/weeks", "assets/preload/data/weeks", "assets/data/weeks"];

        if (ModManager.activeMods != null) {
            for (m in ModManager.activeMods) {
                var modRoot = ModManager.getModFolderRootPath(m);
                weekDirs.unshift('$modRoot/$m/data/weeks');
                weekDirs.unshift('$modRoot/$m/weeks');
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
                var modRoot = ModManager.getModFolderRootPath(m);
                searchRoots.unshift('$modRoot/$m/songs');
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

    private static function parseColorString(raw:String):Null<FlxColor> {
        if (raw == null || raw.length == 0) return null;
        var clean = raw.trim();
        if (clean.startsWith("#")) return FlxColor.fromString(clean);
        if (clean.startsWith("0x") || clean.startsWith("0X")) {
            var hex = clean.substr(2);
            if (hex.length == 6) hex = "FF" + hex;
            if (hex.length == 8) return FlxColor.fromString("#" + hex);
            var parsed = Std.parseInt(clean);
            return parsed != null ? cast parsed : null;
        }
        if (clean.contains(",")) {
            var parts = clean.split(",").map(function(s) return Std.parseInt(s.trim()));
            if (parts.length >= 3) {
                return FlxColor.fromRGB(parts[0], parts[1], parts[2], parts.length > 3 ? parts[3] : 255);
            }
        }
        return FlxColor.fromString("#" + clean);
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
            case "tankman": 0xFFF6B604;
            case "monster": 0xFFF3FF6E;
            case "gf": 0xFFA5004D;
            default: 0xFF282035;
        };
    }
}