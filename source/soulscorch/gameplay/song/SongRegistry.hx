package soulscorch.gameplay.song;

import flixel.util.FlxColor;
import haxe.Json;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.song.Difficulty;
import soulscorch.gameplay.song.SongMetadata;
import soulscorch.scripting.mod.ModLoader;

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
    var color:Int;
    var difficulties:Array<String>;
    var folder:String;
}

class SongRegistry {
    public static var songs:Array<RegisteredSong> = [];

    public static function scanAll():Void {
        songs = [];
        var scannedIds:Map<String, Bool> = new Map();

        #if sys
        scanFolder("assets/songs", scannedIds);

        for (mod in ModLoader.activeMods) {
            scanFolder('mods/$mod/songs', scannedIds);
            scanFolder('mods/$mod/assets/songs', scannedIds);
        }
        #end

        Logger.info('SongRegistry populated with ${songs.length} song(s).', "registry");
    }

    #if sys
    private static function scanFolder(path:String, scannedIds:Map<String, Bool>):Void {
        if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return;

        var entries = FileSystem.readDirectory(path);
        for (entry in entries) {
            var songDir = '$path/$entry';
            if (FileSystem.isDirectory(songDir) && !scannedIds.exists(entry.toLowerCase())) {
                scannedIds.set(entry.toLowerCase(), true);

                var title = entry;
                var artist = "Unknown";
                var charter = "Unknown";
                var bpm = 100.0;
                var char = "dad";
                var color = 0xFF9271FD;
                var diffs = Difficulty.defaultList.copy();

                var metaPath = '$songDir/meta.json';
                if (FileSystem.exists(metaPath)) {
                    try {
                        var raw = File.getContent(metaPath);
                        var meta:SongMetadata = Json.parse(raw);
                        if (meta.title != null) title = meta.title;
                        if (meta.artist != null) artist = meta.artist;
                        if (meta.charter != null) charter = meta.charter;
                        if (meta.bpm != null) bpm = meta.bpm;
                        if (meta.player2 != null) char = meta.player2;
                        if (meta.freeplayIcon != null) char = meta.freeplayIcon;
                        if (meta.difficulties != null && meta.difficulties.length > 0) diffs = meta.difficulties;
                        if (meta.color != null) {
                            var parsedColor = FlxColor.fromString(meta.color);
                            if (parsedColor != null) color = parsedColor;
                        }
                    } catch (e:Dynamic) {
                        Logger.warn('Failed parsing meta in $metaPath: $e', "registry");
                    }
                }

                songs.push({
                    id: entry,
                    title: title,
                    artist: artist,
                    charter: charter,
                    bpm: bpm,
                    character: char,
                    color: color,
                    difficulties: diffs,
                    folder: songDir
                });
            }
        }
    }
    #end
}