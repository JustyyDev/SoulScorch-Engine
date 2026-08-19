package soulscorch.gameplay.song;

import flixel.util.FlxColor;
import haxe.Json;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.ChartParser;
import soulscorch.gameplay.chart.Song;
import soulscorch.gameplay.song.SongMetadata;
import soulscorch.scripting.mod.ModManager;

using StringTools;

class SongLoader {
    public static function load(songId:String, ?difficulty:String = "normal"):Song {
        var cleanSong = (songId == null || songId.trim().length == 0) ? "tutorial" : songId.toLowerCase().trim();
        var cleanDiff = (difficulty == null || difficulty.trim().length == 0) ? "normal" : difficulty.toLowerCase().trim();
        var diffSuffix = (cleanDiff == "normal") ? "" : '-$cleanDiff';

        var chartCandidates = [
            'songs/$cleanSong/charts/$cleanDiff',
            'songs/$cleanSong/chart$diffSuffix',
            'songs/$cleanSong/$cleanSong$diffSuffix',
            'data/$cleanSong/$cleanSong$diffSuffix',
            'data/$cleanSong/$cleanDiff',
            'data/charts/$cleanSong/$cleanDiff',
            'songs/$cleanSong/${cleanSong}_$cleanDiff'
        ];

        if (cleanDiff == "normal") {
            chartCandidates.push('songs/$cleanSong/chart');
            chartCandidates.push('songs/$cleanSong/$cleanSong');
            chartCandidates.push('data/$cleanSong/$cleanSong');
            chartCandidates.push('data/$cleanSong/chart');
        }

        var resolvedChart:String = null;
        for (c in chartCandidates) {
            resolvedChart = AssetResolver.resolveFile(c, [".json", ""]);
            if (resolvedChart != null) break;
        }

        if (resolvedChart == null) {
            Logger.error('Failed resolving song chart for: $cleanSong ($cleanDiff)', "song");
            var fallback = new Song(cleanSong, cleanSong);
            fallback.difficulty = cleanDiff;
            return fallback;
        }

        try {
            var rawJson = AssetResolver.getText(resolvedChart);
            var parsedSong:Song = ChartParser.parse(rawJson, cleanSong);
            parsedSong.difficulty = cleanDiff;

            // Load Metadata (meta.json, _meta.json, song.json)
            var metaCandidates = [
                'songs/$cleanSong/meta',
                'songs/$cleanSong/_meta',
                'data/$cleanSong/meta',
                'data/$cleanSong/_meta'
            ];

            for (m in metaCandidates) {
                var metaRes = AssetResolver.resolveFile(m, [".json", ""]);
                if (metaRes != null) {
                    try {
                        var metaRaw = AssetResolver.getText(metaRes);
                        var meta:SongMetadata = Json.parse(metaRaw);

                        if (meta.title != null && meta.title.trim().length > 0) parsedSong.title = meta.title;
                        if (meta.artist != null) parsedSong.artist = meta.artist;
                        if (meta.charter != null) parsedSong.charter = meta.charter;
                        if (meta.bpm != null && meta.bpm > 0) parsedSong.bpm = meta.bpm;
                        if (meta.stage != null) parsedSong.stage = meta.stage;
                        if (meta.player1 != null) parsedSong.player1 = meta.player1;
                        if (meta.player2 != null) parsedSong.player2 = meta.player2;
                        if (meta.gfVersion != null) parsedSong.gfVersion = meta.gfVersion;
                        if (meta.needsVoices != null) parsedSong.needsVoices = meta.needsVoices == true;

                        if (meta.color != null && meta.color.trim().length > 0) {
                            var parsedColor:Null<FlxColor> = FlxColor.fromString(meta.color);
                            parsedSong.color = (parsedColor != null) ? parsedColor : 0xFF9271FD;
                        }
                    } catch (err:Dynamic) {
                        Logger.warn('Failed parsing metadata for $cleanSong: $err', "song");
                    }
                    break;
                }
            }

            if (parsedSong.chart == null) {
                parsedSong.chart = new Chart(parsedSong.bpm, parsedSong.scrollSpeed);
            }

            return parsedSong;
        } catch (e:Dynamic) {
            Logger.error('Exception parsing chart for $cleanSong: $e', "song");
            var fallback = new Song(cleanSong, cleanSong);
            fallback.difficulty = cleanDiff;
            return fallback;
        }
    }
}