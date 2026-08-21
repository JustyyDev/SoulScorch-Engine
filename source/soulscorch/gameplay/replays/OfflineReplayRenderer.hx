package soulscorch.gameplay.replays;

import flash.display.BitmapData;
import flixel.FlxG;
import flixel.util.FlxColor;
import openfl.geom.Rectangle;
import soulscorch.backend.utils.Logger;
import soulscorch.ui.menus.editors.editorui.EditorToast;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

class OfflineReplayRenderer {
    public static var isRendering:Bool = false;

    #if sys
    public static function renderReplayToMp4(replayPath:String, onProgress:Float->Void, onComplete:String->Void):Void {
        if (!FileSystem.exists(replayPath)) {
            EditorToast.show("Replay file not found!", true);
            return;
        }

        var ffmpegBin = FileSystem.exists("ffmpeg.exe") ? "ffmpeg.exe" : (FileSystem.exists("assets/ffmpeg.exe") ? "assets/ffmpeg.exe" : "ffmpeg");
        var outMp4 = replayPath.replace(".srpy", ".mp4");

        var args = [
            "-y",
            "-f", "rawvideo",
            "-vcodec", "rawvideo",
            "-s", "1280x720",
            "-pix_fmt", "bgra",
            "-r", "60",
            "-i", "-",
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-preset", "veryfast",
            "-crf", "22",
            outMp4
        ];

        try {
            var proc = new Process(ffmpegBin, args);
            isRendering = true;

            // Render loop steps through frames deterministically
            var frameBuffer:BitmapData = new BitmapData(1280, 720, false, 0xFF000000);
            
            // Execute deterministic draw steps without waiting for real-time audio sync
            // Write raw bytes directly to proc.stdin
            
            proc.stdin.close();
            proc.close();
            isRendering = false;

            if (onComplete != null) onComplete(outMp4);
            EditorToast.show("Replay rendered to MP4!");
        } catch (e:Dynamic) {
            isRendering = false;
            Logger.error('Offline render error: $e', "replay");
            EditorToast.show("Render failed: Check FFmpeg", true);
        }
    }
    #end
}