package soulscorch.gameplay.replays;

import flash.display.BitmapData;
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import openfl.geom.Rectangle;
import soulscorch.backend.utils.Logger;
import soulscorch.ui.menus.editors.editorui.EditorToast;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

using StringTools;

class SoulVidEncoder {
    public static inline var SOULVID_HEADER_MAGIC:String = "SOULVID_V1";

    #if sys
    public static function encodeToSoulVid(replayPath:String, onComplete:String->Void):Void {
        if (!FileSystem.exists(replayPath)) {
            EditorToast.show("Replay file missing!", true);
            return;
        }

        var rawReplayText = File.getContent(replayPath);
        var ffmpegBin = FileSystem.exists("ffmpeg.exe") ? "ffmpeg.exe" : (FileSystem.exists("assets/ffmpeg.exe") ? "assets/ffmpeg.exe" : "ffmpeg");
        
        var tempWebm = replayPath.replace(".srpy", "_temp.webm");
        var outSoulVid = replayPath.replace(".srpy", ".soulvid");

        // High compression VP9 settings: under 3MB with crisp note lines
        var args = [
            "-y",
            "-f", "rawvideo",
            "-vcodec", "rawvideo",
            "-s", "1280x720",
            "-pix_fmt", "bgra",
            "-r", "60",
            "-i", "-",
            "-c:v", "libvpx-vp9",
            "-b:v", "0",
            "-crf", "32",
            "-quality", "good",
            "-speed", "4",
            "-pix_fmt", "yuv420p",
            tempWebm
        ];

        try {
            var proc = new Process(ffmpegBin, args);
            // Stream headless frames...
            proc.stdin.close();
            proc.close();

            // Pack custom SoulScorch header into the container
            if (FileSystem.exists(tempWebm)) {
                var videoBytes = File.getBytes(tempWebm);
                var metaBytes = Bytes.ofString(rawReplayText);

                var out = new BytesOutput();
                out.writeString(SOULVID_HEADER_MAGIC);
                out.writeInt32(metaBytes.length);
                out.writeBytes(metaBytes, 0, metaBytes.length);
                out.writeBytes(videoBytes, 0, videoBytes.length);

                File.saveBytes(outSoulVid, out.getBytes());
                FileSystem.deleteFile(tempWebm);

                Logger.info('Successfully packed embeddable .soulvid: $outSoulVid', "soulvid");
                if (onComplete != null) onComplete(outSoulVid);
            }
        } catch (e:Dynamic) {
            Logger.error('SoulVid encoding error: $e', "soulvid");
        }
    }

    public static function extractReplayData(soulVidPath:String):Null<String> {
        if (!FileSystem.exists(soulVidPath)) return null;

        try {
            var bytes = File.getBytes(soulVidPath);
            var header = bytes.getString(0, SOULVID_HEADER_MAGIC.length);
            if (header == SOULVID_HEADER_MAGIC) {
                var metaLen = bytes.getInt32(SOULVID_HEADER_MAGIC.length);
                var jsonStr = bytes.getString(SOULVID_HEADER_MAGIC.length + 4, metaLen);
                return jsonStr;
            }
        } catch (e:Dynamic) {
            Logger.warn('Failed extracting replay data from .soulvid: $e', "soulvid");
        }
        return null;
    }
    #end
}