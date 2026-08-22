package soulscorch.gameplay.song;

import flixel.util.FlxColor;
import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.chart.Chart;
import soulscorch.gameplay.chart.ChartParser;
import soulscorch.gameplay.chart.Song;
import soulscorch.gameplay.song.SongMetadata;

using StringTools;

class SongLoader {
    public static function load(songId:String, ?difficulty:String = "normal"):Song {
        var cleanSong = (songId == null || songId.trim().length == 0) ? "tutorial" : songId.toLowerCase().trim();
        var cleanDiff = (difficulty == null || difficulty.trim().length == 0) ? "normal" : difficulty.toLowerCase().trim();
        var diffSuffix = (cleanDiff == "normal") ? "" : '-$cleanDiff';

        var song:Song = new Song(cleanSong, cleanSong);
        song.difficulty = cleanDiff;

        // 1. Load Song Metadata
        loadMetadata(song, cleanSong);

        // 2. Load Chart
        var chartLoaded = loadXMSoulChart(song, cleanSong, cleanDiff);

        if (!chartLoaded) {
            chartLoaded = loadUniversalJsonChart(song, cleanSong, cleanDiff, diffSuffix);
        }

        if (!chartLoaded) {
            Logger.warn('No valid chart found for [$cleanSong ($cleanDiff)], generating empty fallback chart.', "song");
            if (song.chart == null) {
                song.chart = new Chart(song.bpm, song.scrollSpeed);
            }
        }

        song.scrollSpeed *= Difficulty.getScrollSpeedMultiplier(cleanDiff);

        // 3. Load External Events
        loadEvents(song, cleanSong);

        return song;
    }

    private static function loadMetadata(song:Song, cleanSong:String):Void {
        var metaXml:Access = XMSoul.parse('songs/$cleanSong/meta');
        if (metaXml == null) metaXml = XMSoul.parse('data/$cleanSong/meta');

        if (metaXml != null) {
            song.title = XMSoul.getAttr(metaXml, "displayName", XMSoul.getAttr(metaXml, "title", song.title));
            song.bpm = XMSoul.getFloatAttr(metaXml, "bpm", song.bpm > 0 ? song.bpm : 100.0);
            song.needsVoices = XMSoul.getBoolAttr(metaXml, "needsVoices", false);

            if (metaXml.has.resolve("color")) {
                var c:Null<FlxColor> = SongMetadataHelper.parseColor(metaXml.att.resolve("color"));
                if (c != null) song.color = c;
            }

            if (metaXml.hasNode.resolve("characters")) {
                var cNode = metaXml.node.resolve("characters");
                song.player1 = XMSoul.getAttr(cNode, "player1", song.player1);
                song.player2 = XMSoul.getAttr(cNode, "player2", song.player2);
                song.gfVersion = XMSoul.getAttr(cNode, "gfVersion", song.gfVersion);
            }

            if (metaXml.hasNode.resolve("stage")) {
                song.stage = XMSoul.getAttr(metaXml.node.resolve("stage"), "name", song.stage);
            }
            return;
        }

        var metaCandidates = [
            'songs/$cleanSong/meta.json',
            'songs/$cleanSong/_meta.json',
            'songs/$cleanSong/metadata.json',
            'data/$cleanSong/meta.json',
            'data/$cleanSong/metadata.json',
            'assets/preload/songs/$cleanSong/meta.json'
        ];

        for (m in metaCandidates) {
            var metaRes = AssetResolver.resolveFile(m, [".json", ""]);
            if (metaRes != null) {
                try {
                    var meta:SongMetadata = Json.parse(AssetResolver.getText(metaRes));
                    if (meta.title != null && meta.title.trim().length > 0) song.title = meta.title;
                    if (meta.artist != null) song.artist = meta.artist;
                    if (meta.charter != null) song.charter = meta.charter;
                    if (meta.bpm != null && meta.bpm > 0) song.bpm = meta.bpm;
                    if (meta.stage != null) song.stage = meta.stage;
                    if (meta.player1 != null) song.player1 = meta.player1;
                    if (meta.player2 != null) song.player2 = meta.player2;
                    if (meta.gfVersion != null) song.gfVersion = meta.gfVersion;
                    if (meta.needsVoices != null) song.needsVoices = meta.needsVoices == true;

                    if (meta.color != null && meta.color.trim().length > 0) {
                        var parsedCol:Null<FlxColor> = SongMetadataHelper.parseColor(meta.color);
                        if (parsedCol != null) song.color = parsedCol;
                    }
                } catch (err:Dynamic) {
                    Logger.warn('Failed parsing metadata for $cleanSong: $err', "song");
                }
                break;
            }
        }
    }

    private static function loadXMSoulChart(song:Song, cleanSong:String, cleanDiff:String):Bool {
        var chartXml:Access = XMSoul.parse('songs/$cleanSong/charts/$cleanDiff');
        if (chartXml == null) chartXml = XMSoul.parse('songs/$cleanSong/$cleanDiff');
        if (chartXml == null) chartXml = XMSoul.parse('data/$cleanSong/charts/$cleanDiff');

        if (chartXml == null) return false;

        song.scrollSpeed = XMSoul.getFloatAttr(chartXml, "speed", song.scrollSpeed > 0 ? song.scrollSpeed : 1.0);
        song.chart = new Chart(song.bpm, song.scrollSpeed);

        for (strumNode in chartXml.nodes.resolve("strumLine")) {
            var isPlayer = XMSoul.getAttr(strumNode, "type", "opponent").toLowerCase() == "player" 
                || XMSoul.getAttr(strumNode, "position", "").toLowerCase() == "boyfriend";

            for (noteNode in strumNode.nodes.resolve("note")) {
                var t = XMSoul.getFloatAttr(noteNode, "time", 0.0);
                var dir = XMSoul.getIntAttr(noteNode, "lane", XMSoul.getIntAttr(noteNode, "id", 0));
                var len = XMSoul.getFloatAttr(noteNode, "len", XMSoul.getFloatAttr(noteNode, "sLen", 0.0));
                var type = XMSoul.getAttr(noteNode, "type", "normal");

                song.chart.addNote(t, dir, len, type, isPlayer);
            }
        }

        Logger.info('Successfully parsed .xmsoul chart: songs/$cleanSong/charts/$cleanDiff.xmsoul', "song");
        return true;
    }

    private static function loadUniversalJsonChart(song:Song, cleanSong:String, cleanDiff:String, diffSuffix:String):Bool {
        var chartCandidates = [
            'songs/$cleanSong/charts/$cleanDiff',
            'songs/$cleanSong/chart$diffSuffix',
            'songs/$cleanSong/$cleanSong$diffSuffix',
            'data/$cleanSong/$cleanSong$diffSuffix',
            'data/$cleanSong/$cleanDiff',
            'assets/preload/songs/$cleanSong/charts/$cleanDiff',
            'songs/$cleanSong/$cleanDiff'
        ];

        if (cleanDiff == "normal") {
            chartCandidates.push('songs/$cleanSong/chart');
            chartCandidates.push('songs/$cleanSong/$cleanSong');
            chartCandidates.push('data/$cleanSong/$cleanSong');
            chartCandidates.push('assets/preload/songs/$cleanSong/charts/normal');
        }

        var resolvedChart:String = null;
        for (c in chartCandidates) {
            resolvedChart = AssetResolver.resolveFile(c, [".json", ""]);
            if (resolvedChart != null) break;
        }

        if (resolvedChart == null) return false;

        try {
            var rawJson = AssetResolver.getText(resolvedChart);
            var parsed:Song = ChartParser.parse(rawJson, cleanSong);
            if (parsed != null && parsed.chart != null) {
                song.chart = parsed.chart;
                if (song.bpm <= 0 && parsed.bpm > 0) song.bpm = parsed.bpm;
                if (parsed.scrollSpeed > 0) song.scrollSpeed = parsed.scrollSpeed;
                if (parsed.player1 != null && song.player1 == null) song.player1 = parsed.player1;
                if (parsed.player2 != null && song.player2 == null) song.player2 = parsed.player2;
                if (parsed.stage != null && song.stage == null) song.stage = parsed.stage;
                return true;
            }
        } catch (e:Dynamic) {
            Logger.error('Failed parsing JSON chart for $cleanSong: $e', "song");
        }
        return false;
    }

    private static function loadEvents(song:Song, cleanSong:String):Void {
        var eventsXml:Access = XMSoul.parse('songs/$cleanSong/events');
        if (eventsXml == null) eventsXml = XMSoul.parse('data/$cleanSong/events');

        if (eventsXml != null && song.chart != null) {
            for (evNode in eventsXml.nodes.resolve("event")) {
                var time = XMSoul.getFloatAttr(evNode, "time", 0.0);
                var name = XMSoul.getAttr(evNode, "name", "");
                var target = XMSoul.getAttr(evNode, "target", XMSoul.getAttr(evNode, "val1", "0"));
                var anim = XMSoul.getAttr(evNode, "anim", XMSoul.getAttr(evNode, "val2", ""));

                song.chart.addEvent(time, name, target, anim);
            }
        }
    }
}