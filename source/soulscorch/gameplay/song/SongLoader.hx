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

        var chartCandidates = [
            'assets/data/$cleanSong/$cleanSong-$cleanDiff.json',
            'assets/data/$cleanSong/$cleanDiff.json',
            'assets/songs/$cleanSong/$cleanSong-$cleanDiff.json',
            'assets/songs/$cleanSong/$cleanDiff.json',
            'data/$cleanSong/$cleanSong-$cleanDiff.json',
            'data/charts/$cleanSong/$cleanDiff.json'
        ];

        // If normal difficulty, also try the filename
        if (cleanDiff == "normal") {
            chartCandidates.push('assets/data/$cleanSong/$cleanSong.json');
            chartCandidates.push('assets/songs/$cleanSong/$cleanSong.json');
            chartCandidates.push('data/$cleanSong/$cleanSong.json');
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
            var blankSong = new Song(cleanSong, cleanSong);
            blankSong.chart = new Chart();
            return blankSong;
        }

        try {
            var rawJson = AssetResolver.getText(resolvedChart);
            var parsedSong:Song = ChartParser.parse(rawJson);

            // 2. Search for meta.json
            var metaCandidates = [
                'assets/data/$cleanSong/meta.json',
                'assets/songs/$cleanSong/meta.json',
                'data/$cleanSong/meta.json'
            ];

            for (m in metaCandidates) {
                var metaRes = ModLoader.getPath(m);
                if (AssetResolver.exists(metaRes)) {
                    try {
                        var metaRaw = AssetResolver.getText(metaRes);
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
                    } catch (err:Dynamic) {}
                    break;
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