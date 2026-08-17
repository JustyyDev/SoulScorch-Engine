package soulscorch.graphics.video;

import flixel.FlxSprite;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;

#if (hxvlc || hxCodec)
#if hxvlc
import hxvlc.flixel.FlxVideoSprite as NativeVideoSprite;
#elseif hxCodec
import hxcodec.flixel.FlxVideoSprite as NativeVideoSprite;
#end
#end

class VideoSprite extends FlxSprite {
    #if (hxvlc || hxCodec)
    private var nativeVideo:NativeVideoSprite;
    #end

    public var isPlaying:Bool = false;
    public var onFinish:Void->Void;

    public function new(x:Float = 0, y:Float = 0) {
        super(x, y);
        #if (hxvlc || hxCodec)
        nativeVideo = new NativeVideoSprite(x, y);
        #else
        makeGraphic(640, 360, 0xFF000000);
        #end
    }

    public function playVideo(videoPath:String, loop:Bool = false):Bool {
        var resolved = ModLoader.getPath(videoPath);
        if (!AssetResolver.exists(resolved)) {
            Logger.warn('Video file not found at: $resolved', "video");
            return false;
        }

        #if (hxvlc || hxCodec)
        if (nativeVideo != null) {
            nativeVideo.bitmap.onEndReached.add(function() {
                isPlaying = false;
                if (onFinish != null) onFinish();
            });
            nativeVideo.load(resolved, loop ? [':input-repeat=65535'] : []);
            nativeVideo.play();
            isPlaying = true;
            return true;
        }
        #end

        Logger.info('Video playback requested for: $videoPath (Native video codec not linked).', "video");
        return false;
    }

    public function pauseVideo():Void {
        #if (hxvlc || hxCodec)
        if (nativeVideo != null && isPlaying) {
            nativeVideo.pause();
            isPlaying = false;
        }
        #end
    }

    public function resumeVideo():Void {
        #if (hxvlc || hxCodec)
        if (nativeVideo != null && !isPlaying) {
            nativeVideo.resume();
            isPlaying = true;
        }
        #end
    }

    public function stopVideo():Void {
        #if (hxvlc || hxCodec)
        if (nativeVideo != null) {
            nativeVideo.stop();
            isPlaying = false;
        }
        #end
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        #if (hxvlc || hxCodec)
        if (nativeVideo != null) {
            nativeVideo.update(elapsed);
        }
        #end
    }

    override public function destroy():Void {
        stopVideo();
        #if (hxvlc || hxCodec)
        if (nativeVideo != null) {
            nativeVideo.destroy();
            nativeVideo = null;
        }
        #end
        super.destroy();
    }
}