package soulscorch.gameplay.song;

import haxe.Json;
import flixel.util.FlxColor;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.ChartParser;
import soulscorch.gameplay.song.Song;
import soulscorch.gameplay.song.SongMetadata;
import soulscorch.scripting.ModLoader;

class SongLoader {
    /**
     * Resolves chart JSON and metadata across mods and base assets to return a structured Song instance.
     */
    public static function load(songId:String, difficulty:String = "normal"):Song {
        var diffName = (difficulty == null || difficulty.length == 0) ? "normal" : difficulty.toLowerCase().trim();
        var diffSuffix = Difficulty.getSuffix(diffName);

        var possibleChartPaths = [
            'assets/songs/$songId/charts/$diffName.json',
            'assets/songs/$songId/charts/normal.json',
            'assets/songs/$songId/chart$diffSuffix.json',
            'assets/songs/$songId/$songId$diffSuffix.json',
            'assets/songs/$songId/chart.json',
            'assets/songs/$songId/$songId.json'
        ];

        var chartPath:String = null;
        for (path in possibleChartPaths) {
            var resolved = ModLoader.getPath(path);
            if (AssetResolver.exists(resolved)) {
                chartPath = resolved;
                break;
            }
        }

        if (chartPath == null) {
            Logger.error('Missing chart file for song "$songId" [$diffName]', "loader");
            throw 'Chart file missing for: $songId ($diffName)';
        }

        var chartRaw = AssetResolver.getText(chartPath);
        var song = ChartParser.parse(chartRaw);
        song.id = songId;
        song.difficulty = diffName;

        // Apply metadata overrides if present
        var metaPath = ModLoader.getPath('assets/songs/$songId/meta.json');
        if (AssetResolver.exists(metaPath)) {
            try {
                var metaRaw = AssetResolver.getText(metaPath);
                var meta:SongMetadata = Json.parse(metaRaw);

                if (meta.title != null) song.title = meta.title;
                if (meta.artist != null) song.artist = meta.artist;
                if (meta.charter != null) song.charter = meta.charter;
                if (meta.stage != null) song.stage = meta.stage;
                if (meta.player1 != null) song.player1 = meta.player1;
                if (meta.player2 != null) song.player2 = meta.player2;
                if (meta.gfVersion != null) song.gfVersion = meta.gfVersion;
                if (meta.needsVoices != null) song.needsVoices = meta.needsVoices;
                if (meta.color != null) song.color = FlxColor.fromString(meta.color);
            } catch (e:Dynamic) {
                Logger.warn('Failed parsing song metadata for $songId: $e', "loader");
            }
        }

        Logger.info('Song "$songId" [$diffName] loaded successfully (BPM: ${song.bpm}, Speed: ${song.scrollSpeed}).', "loader");
        return song;
    }
}