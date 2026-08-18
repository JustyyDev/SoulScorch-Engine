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
        var cleanSong = (songId == null || songId.trim().length == 0) ? "tutorial" : songId.toLowerCase().trim();
        var cleanDiff = (difficulty == null || difficulty.trim().length == 0) ? "normal" : difficulty.toLowerCase().trim();

        var chartCandidates = [
            'data/charts/$cleanSong/$cleanDiff.json',
            'data/$cleanSong/$cleanSong-$cleanDiff.json',
            'data/$cleanSong/${cleanSong}_$cleanDiff.json',
            'data/$cleanSong/$cleanDiff.json',
            'assets/data/$cleanSong/$cleanSong-$cleanDiff.json',
            'assets/data/$cleanSong/$cleanDiff.json',
            'assets/songs/$cleanSong/charts/$cleanDiff.json',
            'assets/songs/$cleanSong/chart-${cleanDiff}.json',
            'assets/songs/$cleanSong/$cleanSong-$cleanDiff.json'
        ];

        if (cleanDiff == "normal") {
            chartCandidates.unshift('data/$cleanSong/$cleanSong.json');
            chartCandidates.unshift('data/$cleanSong/chart.json');
            chartCandidates.push('assets/data/$cleanSong/$cleanSong.json');
            chartCandidates.push('assets/songs/$cleanSong/chart.json');
            chartCandidates.push('assets/songs/$cleanSong/$cleanSong.json');
        }

        var resolvedChart:String = null;
        for (c in chartCandidates) {
            var res = ModLoader.getPath(c);
            if (AssetResolver.exists(res)) {
                resolvedChart = res;
                break;
            }
        }

        if (resolvedChart == null) {
            Logger.error('Failed to resolve song chart for: $cleanSong ($cleanDiff)', "song");
            var fallback = new Song(cleanSong, cleanSong);
            if (fallback.chart == null) fallback.chart = new Chart();
            return fallback;
        }

        try {
            var rawJson = AssetResolver.getText(resolvedChart);
            var parsedSong:Song = ChartParser.parse(rawJson);
            if (parsedSong == null) {
                var fallback = new Song(cleanSong, cleanSong);
                if (fallback.chart == null) fallback.chart = new Chart();
                return fallback;
            }

            var metaCandidates = [
                'data/$cleanSong/meta.json',
                'assets/data/$cleanSong/meta.json',
                'assets/songs/$cleanSong/meta.json'
            ];

            for (m in metaCandidates) {
                var metaRes = ModLoader.getPath(m);
                if (AssetResolver.exists(metaRes)) {
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
                        if (meta.needsVoices != null) parsedSong.needsVoices = meta.needsVoices;
                        
                        if (meta.color != null && meta.color.trim().length > 0) {
                            var parsedColor:Null<FlxColor> = FlxColor.fromString(meta.color);
                            parsedSong.color = (parsedColor != null) ? parsedColor : 0xFF9271FD;
                        }
                    } catch (err:Dynamic) {
                        Logger.warn('Failed parsing meta for $cleanSong: $err', "song");
                    }
                    break;
                }
            }

            if (parsedSong.chart == null) {
                parsedSong.chart = new Chart();
            }

            return parsedSong;
        } catch (e:Dynamic) {
            Logger.error('Exception parsing chart for $cleanSong: $e', "song");
            var fallback = new Song(cleanSong, cleanSong);
            if (fallback.chart == null) fallback.chart = new Chart();
            return fallback;
        }
    }
}