package soulscorch.gameplay.replays;

import flash.display.BitmapData;
import flash.geom.Matrix;
import flash.geom.Rectangle;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;
import openfl.display.PNGEncoderOptions;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.system.SaveData;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.GameplayFlags;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

using StringTools;

typedef InputPressEvent = {
    var time:Float;
    var direction:Int;
    var pressed:Bool;
}

typedef ReplayData = {
    var songName:String;
    var difficulty:String;
    var timestamp:String;
    var events:Array<InputPressEvent>;
    var ?score:Int;
    var ?accuracy:Float;
    var ?misses:Int;
    var ?rank:String;
}

class ReplayManager {
    public static var recording:Bool = false;
    public static var playing:Bool = false;
    private static inline var REPLAY_DIR:String = "replays";
    
    private static var recordedEvents:Array<InputPressEvent> = [];
    private static var playbackIndex:Int = 0;
    private static var currentReplay:ReplayData = null;
    private static var playbackBuffer:Array<InputPressEvent> = [];

    public static function startRecording(song:String, diff:String):Void {
        recording = true;
        stopPlayback();
        if (recordedEvents == null) recordedEvents = [];
        recordedEvents.resize(0);
        Logger.info('[REPLAY] Started recording replay for $song ($diff)', "replay");
    }

    public static function stopPlayback():Void {
        playing = false;
        playbackIndex = 0;
        currentReplay = null;
    }

    public static function recordInput(dir:Int, pressed:Bool):Void {
        if (!recording) return;
        recordedEvents.push({
            time: Conductor.songPosition,
            direction: dir,
            pressed: pressed
        });
    }

    public static function saveReplay(song:String, diff:String, score:Int = 0, acc:Float = 0.0, misses:Int = 0, rank:String = "Clear"):String {
        if (!recording) return null;
        recording = false;

        var capturedEvents = recordedEvents.copy();

        var data:ReplayData = {
            songName: song,
            difficulty: diff,
            timestamp: Date.now().toString(),
            events: capturedEvents,
            score: score,
            accuracy: acc,
            misses: misses,
            rank: rank
        };

        var json = Json.stringify(data, "\t");
        var baseId = '${song}_${diff}_${Std.int(Date.now().getTime())}';
        var filename = '$REPLAY_DIR/$baseId.srpy';
        var cardPath = '$REPLAY_DIR/$baseId.png';

        #if sys
        try {
            if (!FileSystem.exists(REPLAY_DIR)) FileSystem.createDirectory(REPLAY_DIR);
            File.saveContent(filename, json);
            Logger.info('[REPLAY] Saved replay file: $filename', "replay");

            // Generate instant embeddable Discord summary card
            generateReplayCard(data, cardPath);

            if (SaveData.instance != null) {
                SaveData.instance.registerReplay({
                    id: baseId,
                    songId: song,
                    difficulty: diff,
                    timestamp: Date.now().getTime(),
                    dateString: Date.now().toString(),
                    score: score,
                    accuracy: acc,
                    misses: misses,
                    replayPath: filename,
                    mp4Path: FileSystem.exists(filename.replace(".srpy", ".mp4")) ? filename.replace(".srpy", ".mp4") : null
                });
            }
        } catch (e:Dynamic) {
            Logger.error('[REPLAY] Failed to save replay file: $e', "replay");
        }
        #end

        return filename;
    }

    public static function loadReplay(filePath:String):Bool {
        #if sys
        if (FileSystem.exists(filePath)) {
            try {
                var content = File.getContent(filePath);
                return loadReplayFromJson(content);
            } catch (e:Dynamic) {
                Logger.error('[REPLAY] Failed loading replay from disk: $e', "replay");
            }
        }
        #end
        return false;
    }

    public static function loadReplayFromJson(jsonString:String):Bool {
        try {
            currentReplay = Json.parse(jsonString);
            if (currentReplay == null || currentReplay.events == null) return false;

            currentReplay.events.sort(function(a, b) {
                if (a.time < b.time) return -1;
                if (a.time > b.time) return 1;
                return 0;
            });
            playbackIndex = 0;
            playing = true;
            recording = false;
            Logger.info('[REPLAY] Loaded replay payload successfully', "replay");
            return true;
        } catch (e:Dynamic) {
            Logger.error('[REPLAY] Corrupted replay JSON: $e', "replay");
        }
        return false;
    }

    public static function getNextPlaybackEvents():Array<InputPressEvent> {
        playbackBuffer.resize(0);
        if (!playing || currentReplay == null || currentReplay.events == null) return playbackBuffer;

        var eventList = currentReplay.events;
        var songPos = Conductor.songPosition;

        while (playbackIndex < eventList.length) {
            var ev = eventList[playbackIndex];
            if (ev.time <= songPos) {
                playbackBuffer.push(ev);
                playbackIndex++;
            } else {
                break;
            }
        }

        if (playbackIndex >= eventList.length) {
            stopPlayback();
        }

        return playbackBuffer;
    }

    #if sys
    public static function generateReplayCard(data:ReplayData, outputPath:String):Void {
        try {
            var width:Int = 720;
            var height:Int = 380;
            var bmp = new BitmapData(width, height, false, 0xFF0B0C10);

            // Top Banner
            var header = new BitmapData(width, 70, false, 0xFF141721);
            bmp.copyPixels(header, new Rectangle(0, 0, width, 70), new flash.geom.Point(0, 0));

            var songTxt = new FlxText(25, 12, width - 50, data.songName.toUpperCase() + ' [' + data.difficulty.toUpperCase() + ']', 24);
            songTxt.setFormat(Paths.font("vcr"), 24, 0xFF00FFCC, LEFT);
            songTxt.draw();
            stampText(bmp, songTxt, 25, 12);

            var metaTxt = new FlxText(25, 42, width - 50, 'SOULSCORCH REPLAY MATRIX  •  ' + data.timestamp, 14);
            metaTxt.setFormat(Paths.font("vcr"), 14, 0xFF888899, LEFT);
            metaTxt.draw();
            stampText(bmp, metaTxt, 25, 42);

            var statTxt = new FlxText(30, 100, 400, 'Score: ' + (data.score != null ? data.score : 0) + '\nAccuracy: ' + (data.accuracy != null ? Math.round(data.accuracy * 100) / 100 : 0) + '%\nMisses: ' + (data.misses != null ? data.misses : 0), 22);
            statTxt.setFormat(Paths.font("vcr"), 22, 0xFFFFFFFF, LEFT);
            statTxt.draw();
            stampText(bmp, statTxt, 30, 100);

            var rankTxt = new FlxText(450, 110, 240, data.rank != null ? data.rank : "CLEAR", 56);
            rankTxt.setFormat(Paths.font("vcr"), 56, 0xFF00FFCC, CENTER);
            rankTxt.draw();
            stampText(bmp, rankTxt, 450, 110);

            var bytes = bmp.encode(new Rectangle(0, 0, width, height), new PNGEncoderOptions());
            File.saveBytes(outputPath, bytes);
        } catch (e:Dynamic) {
            Logger.warn('[REPLAY] Replay card render failed: $e', "replay");
        }
    }

    private static function stampText(target:BitmapData, txt:FlxText, x:Float, y:Float):Void {
        var mat = new Matrix();
        mat.translate(x, y);
        target.draw(txt.pixels, mat);
    }
    #end

    public static function getAllReplays():Array<String> {
        var list:Array<String> = [];
        #if sys
        if (FileSystem.exists(REPLAY_DIR) && FileSystem.isDirectory(REPLAY_DIR)) {
            for (f in FileSystem.readDirectory(REPLAY_DIR)) {
                if (f.endsWith(".srpy") || f.endsWith(".soulvid")) {
                    list.push('$REPLAY_DIR/$f');
                }
            }
            list.sort(function(a, b) {
                if (a < b) return -1;
                if (a > b) return 1;
                return 0;
            });
        }
        #end
        return list;
    }
}