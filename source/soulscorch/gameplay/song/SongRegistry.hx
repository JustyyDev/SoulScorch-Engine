package soulscorch.gameplay.song;

import flixel.util.FlxColor;
import haxe.Json;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.song.Difficulty;
import soulscorch.gameplay.song.SongMetadata;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef RegisteredSong = {
    var id:String;
    var title:String;
    var artist:String;
    var charter:String;
    var bpm:Float;
    var character:String;
    var color:FlxColor;
    var difficulties:Array<String>;
    var folder:String;
    var ?mod:String;
}

class SongRegistry {
    public static var songs:Array<RegisteredSong> = [];
    private static var songsById:Map<String, RegisteredSong> = new Map<String, RegisteredSong>();

    public static function scanAll():Void {
        songs = [];
        songsById.clear();
        var scannedIds:Map<String, Bool> = new Map<String, Bool>();

        #if sys
        // 1. Scan from active mods first (highest priority)
        if (ModManager.activeMods != null) {
            for (mod in ModManager.activeMods) {
                scanFolder('mods/$mod/songs', scannedIds, mod);
                scanFolder('mods/$mod/data', scannedIds, mod);
                scanFolder('mods/$mod/assets/songs', scannedIds, mod);
                scanFolder('mods/$mod/assets/data', scannedIds, mod);
            }
        }

        // 2. Scan core base assets
        scanFolder("assets/songs", scannedIds, null);
        scanFolder("assets/data", scannedIds, null);
        scanFolder("assets/preload/songs", scannedIds, null);
        scanFolder("assets/shared/songs", scannedIds, null);
        #end

        Logger.info('SongRegistry populated with ${songs.length} song(s).', "registry");
    }

    #if sys
    private static function scanFolder(path:String, scannedIds:Map<String, Bool>, ?modName:String):Void {
        if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return;

        var entries = FileSystem.readDirectory(path);
        for (entry in entries) {
            var songDir = '$path/$entry';
            var lowerId = entry.toLowerCase().trim();

            if (FileSystem.isDirectory(songDir) && !scannedIds.exists(lowerId)) {
                // Ensure the directory contains at least one chart JSON or meta file
                var contents = FileSystem.readDirectory(songDir);
                var hasValidSongFiles = false;
                for (file in contents) {
                    if (file.endsWith(".json") || file.endsWith(".ogg") || file.endsWith(".hx")) {
                        hasValidSongFiles = true;
                        break;
                    }
                }
                if (!hasValidSongFiles) continue;

                scannedIds.set(lowerId, true);

                var title = entry;
                var artist = "Unknown";
                var charter = "Unknown";
                var bpm = 100.0;
                var char = "dad";
                var color:FlxColor = 0xFF9271FD;
                var detectedDiffs:Array<String> = [];

                // Discover available difficulties from existing files
                for (file in contents) {
                    if (file.endsWith(".json")) {
                        var baseName = file.substr(0, file.length - 5).toLowerCase();
                        for (d in Difficulty.defaultList) {
                            if (baseName == d || baseName.endsWith('-$d') || baseName.endsWith('_$d')) {
                                if (!detectedDiffs.contains(d)) detectedDiffs.push(d);
                            }
                        }
                    }
                }

                if (detectedDiffs.length == 0) {
                    detectedDiffs = Difficulty.defaultList.copy();
                }

                var metaCandidates = ['$songDir/meta.json', '$songDir/_meta.json'];
                for (m in metaCandidates) {
                    if (FileSystem.exists(m)) {
                        try {
                            var raw = File.getContent(m);
                            var meta:SongMetadata = Json.parse(raw);
                            if (meta.title != null) title = meta.title;
                            if (meta.artist != null) artist = meta.artist;
                            if (meta.charter != null) charter = meta.charter;
                            if (meta.bpm != null) bpm = meta.bpm;
                            if (meta.player2 != null) char = meta.player2;
                            if (meta.freeplayIcon != null) char = meta.freeplayIcon;
                            if (meta.icon != null) char = meta.icon;
                            if (meta.difficulties != null && meta.difficulties.length > 0) detectedDiffs = meta.difficulties;
                            if (meta.color != null) {
                                var parsedColor = FlxColor.fromString(meta.color);
                                if (parsedColor != null) color = parsedColor;
                            }
                        } catch (e:Dynamic) {
                            Logger.warn('Failed parsing meta in $m: $e', "registry");
                        }
                        break;
                    }
                }

                var registered:RegisteredSong = {
                    id: entry,
                    title: title,
                    artist: artist,
                    charter: charter,
                    bpm: bpm,
                    character: char,
                    color: color,
                    difficulties: detectedDiffs,
                    folder: songDir,
                    mod: modName
                };

                songs.push(registered);
                songsById.set(lowerId, registered);
            }
        }
    }
    #end

    public static function getSong(songId:String):Null<RegisteredSong> {
        if (songId == null) return null;
        return songsById.get(songId.toLowerCase().trim());
    }

    public static function hasSong(songId:String):Bool {
        if (songId == null) return false;
        return songsById.exists(songId.toLowerCase().trim());
    }
}