package soulscorch.gameplay.replays;

import haxe.Json;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

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
}

class ReplayManager {
    public static var recording:Bool = false;
    public static var playing:Bool = false;
    
    private static var recordedEvents:Array<InputPressEvent> = [];
    private static var playbackIndex:Int = 0;
    private static var currentReplay:ReplayData = null;

    public static function startRecording(song:String, diff:String):Void {
        recording = true;
        playing = false;
        recordedEvents = [];
        Logger.info('[REPLAY] Started recording replay for $song ($diff)', "replay");
    }

    public static function recordInput(dir:Int, pressed:Bool):Void {
        if (!recording) return;
        recordedEvents.push({
            time: Conductor.songPosition,
            direction: dir,
            pressed: pressed
        });
    }

    public static function saveReplay(song:String, diff:String):Void {
        if (!recording) return;
        recording = false;

        var data:ReplayData = {
            songName: song,
            difficulty: diff,
            timestamp: Date.now().toString(),
            events: recordedEvents
        };

        var json = Json.stringify(data, "\t");
        #if sys
        try {
            if (!FileSystem.exists("replays")) FileSystem.createDirectory("replays");
            var filename = 'replays/${song}_${diff}_${Std.int(Date.now().getTime())}.srpy';
            File.saveContent(filename, json);
            Logger.info('[REPLAY] Successfully saved replay to $filename', "replay");
        } catch (e:Dynamic) {
            Logger.error('[REPLAY] Failed to save replay file: $e', "replay");
        }
        #end
    }

    public static function loadReplay(filePath:String):Bool {
        #if sys
        if (FileSystem.exists(filePath)) {
            try {
                var content = File.getContent(filePath);
                currentReplay = Json.parse(content);
                playbackIndex = 0;
                playing = true;
                recording = false;
                Logger.info('[REPLAY] Loaded replay successfully: $filePath', "replay");
                return true;
            } catch (e:Dynamic) {
                Logger.error('[REPLAY] Failed loading replay: $e', "replay");
            }
        }
        #end
        return false;
    }

    public static function getNextPlaybackEvents():Array<InputPressEvent> {
        var triggered:Array<InputPressEvent> = [];
        if (!playing || currentReplay == null || currentReplay.events == null) return triggered;

        while (playbackIndex < currentReplay.events.length) {
            var ev = currentReplay.events[playbackIndex];
            if (ev.time <= Conductor.songPosition) {
                triggered.push(ev);
                playbackIndex++;
            } else {
                break;
            }
        }
        return triggered;
    }
}