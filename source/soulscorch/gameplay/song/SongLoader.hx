package soulscorch.gameplay.song;

import flixel.util.FlxColor;
import haxe.Json;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.ChartParser;
import soulscorch.gameplay.chart.Song;
import soulscorch.gameplay.song.SongMetadata;
import soulscorch.scripting.mod.ModLoader;

using StringTools;

class SongLoader {
    public static function load(songId:String, ?difficulty:String = "normal"):Song {
        var cleanSong = (songId == null || songId.length == 0) ? "tutorial" : songId.toLowerCase().trim();
        var cleanDiff = (difficulty == null || difficulty.length == 0) ? "normal" : difficulty.toLowerCase().trim();

        var jsonPath = 'assets/songs/$cleanSong/$cleanSong-$cleanDiff.json';
        if (cleanDiff == "normal" && !AssetResolver.exists(ModLoader.getPath(jsonPath))) {
            jsonPath = 'assets/songs/$cleanSong/$cleanSong.json';
        }

        var resolved = ModLoader.getPath(jsonPath);
        if (!AssetResolver.exists(resolved)) {
            resolved = ModLoader.getPath('data/charts/$cleanSong/$cleanDiff.json');
        }

        if (!AssetResolver.exists(resolved)) {
            Logger.error('Failed to resolve song chart for: $cleanSong ($cleanDiff)', "song");
            var blankSong = new Song(cleanSong, cleanSong);
            blankSong.chart = new Chart();
            return blankSong;
        }

        try {
            var rawJson = AssetResolver.getText(resolved);
            var parsedSong:Song = ChartParser.parse(rawJson);

            var metaPath = ModLoader.getPath('assets/songs/$cleanSong/meta.json');
            if (AssetResolver.exists(metaPath)) {
                try {
                    var metaRaw = AssetResolver.getText(metaPath);
                    var meta:SongMetadata = Json.parse(metaRaw);

                    if (meta.title != null) parsedSong.title = meta.title;
                    if (meta.artist != null) parsedSong.artist = meta.artist;
                    if (meta.charter != null) parsedSong.charter = meta.charter;
                    if (meta.stage != null) parsedSong.stage = meta.stage;
                    if (meta.player1 != null) parsedSong.player1 = meta.player1;
                    if (meta.player2 != null) parsedSong.player2 = meta.player2;
                    if (meta.gfVersion != null) parsedSong.gfVersion = meta.gfVersion;
                    if (meta.needsVoices != null) parsedSong.needsVoices = meta.needsVoices;
                    if (meta.color != null) parsedSong.color = FlxColor.fromString(meta.color);
                } catch (err:Dynamic) {
                    Logger.warn('Could not read meta.json for $cleanSong: $err', "song");
                }
            }

            return parsedSong;
        } catch (e:Dynamic) {
            Logger.error('Exception parsing chart for $cleanSong: $e', "song");
            var blankSong = new Song(cleanSong, cleanSong);
            blankSong.chart = new Chart();
            return blankSong;
        }
    }
}