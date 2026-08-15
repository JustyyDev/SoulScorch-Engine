package soulscorch.gameplay;

import haxe.Json;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModLoader;

class SongLoader {
    public static function load(songId:String, difficulty:String = "normal"):Song {
        var diffSuffix = (difficulty.toLowerCase() == "normal" || difficulty == "") ? "" : '-$difficulty';
        
        var chartPath = ModLoader.getPath('assets/songs/$songId/chart$diffSuffix.json');
        if (!AssetResolver.exists(chartPath)) {
            chartPath = ModLoader.getPath('assets/songs/$songId/$songId$diffSuffix.json');
        }
        if (!AssetResolver.exists(chartPath)) {
            chartPath = ModLoader.getPath('assets/songs/$songId/chart.json');
        }
        if (!AssetResolver.exists(chartPath)) {
            chartPath = ModLoader.getPath('assets/songs/$songId/$songId.json');
        }

        if (!AssetResolver.exists(chartPath)) {
            throw 'Chart file missing: $chartPath';
        }

        var chartRaw = AssetResolver.getText(chartPath);
        var song = ChartParser.parse(chartRaw);
        song.id = songId;
        song.difficulty = difficulty;

        var metadataPath = ModLoader.getPath('assets/songs/$songId/meta.json');
        if (AssetResolver.exists(metadataPath)) {
            try {
                var metaRaw = AssetResolver.getText(metadataPath);
                var meta:Dynamic = Json.parse(metaRaw);
                if (meta.title != null) song.title = meta.title;
                if (meta.stage != null) song.stage = meta.stage;
                if (meta.player1 != null) song.player1 = meta.player1;
                if (meta.player2 != null) song.player2 = meta.player2;
                if (meta.gfVersion != null) song.gfVersion = meta.gfVersion;
            } catch (e:Dynamic) {}
        }

        return song;
    }
}