package soulscorch.gameplay.cutscenes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;
import soulscorch.graphics.JuiceManager;
import soulscorch.scripting.ScriptManager;

typedef SubtitleEntry = {
    var time:Float;
    var text:String;
}

typedef VideoEventEntry = {
    var time:Float;
    var action:String;
    var val1:String;
    var val2:String;
}

class SoulVideoPlayer extends flixel.FlxSubState {
    private var videoSprite:FlxSprite;
    private var subtitleText:FlxText;
    
    private var totalFrames:Int = 0;
    private var currentFrame:Float = 0;
    private var frameRate:Float = 24.0;
    private var isPlaying:Bool = false;
    private var isAtlasMode:Bool = false;
    
    private var audioTrack:FlxSound;
    private var onComplete:Void->Void;
    private var videoPath:String;

    private var subtitles:Array<SubtitleEntry> = [];
    private var videoEvents:Array<VideoEventEntry> = [];
    private var script:ScriptManager;

    public function new(videoKey:String, ?onComplete:Void->Void) {
        super();
        this.videoPath = videoKey;
        this.onComplete = onComplete;
        this.persistentUpdate = true;
        this.persistentDraw = true;
    }

    override public function create():Void {
        super.create();

        videoSprite = new FlxSprite(0, 0);
        videoSprite.screenCenter();
        add(videoSprite);

        // Subtitle text overlay layer
        subtitleText = new FlxText(0, FlxG.height - 100, FlxG.width, "", 24);
        subtitleText.setFormat(Paths.font("vcr"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        subtitleText.scrollFactor.set();
        add(subtitleText);

        parseAndPlayVideo(videoPath);
    }

    private function parseAndPlayVideo(key:String):Void {
        var access = XMSoul.parse(key);
        if (access == null) {
            access = XMSoul.parse('videos/$key');
        }

        if (access != null) {
            frameRate = XMSoul.getFloatAttr(access, "fps", 24.0);
            var audioName = XMSoul.getAttr(access, "audio", "");
            var smoothing = XMSoul.getBoolAttr(access, "smoothing", true);
            videoSprite.antialiasing = smoothing;

            if (access.has.bgColor) {
                var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromString(access.att.bgColor));
                add(bg);
                remove(bg);
                insert(0, bg); // Put background behind video sprite
            }

            // Audio track setup
            if (audioName != "") {
                audioTrack = FlxG.sound.play(Paths.sound(audioName));
                if (audioTrack == null) audioTrack = FlxG.sound.play(Paths.music(audioName));
            }

            // Atlas Mode vs Loose Frames Mode
            if (access.hasNode.atlas) {
                isAtlasMode = true;
                var atlasNode = access.node.atlas;
                var atlasPath = XMSoul.getAttr(atlasNode, "path", "");
                var atlasFrames = Paths.getSparrowAtlas(atlasPath);
                if (atlasFrames != null) {
                    videoSprite.frames = atlasFrames;
                    totalFrames = videoSprite.animation.numFrames;
                }
            } else if (access.hasNode.frames) {
                isAtlasMode = false;
                // Falls back to loose frame sequences if desired
            }

            // Load Subtitles
            if (access.hasNode.subtitles) {
                for (subNode in access.node.subtitles.nodes.sub) {
                    subtitles.push({
                        time: XMSoul.getFloatAttr(subNode, "time", 0.0),
                        text: XMSoul.getAttr(subNode, "text", "")
                    });
                }
            }

            // Load Timed Video Events
            if (access.hasNode.events) {
                for (evNode in access.node.events.nodes.event) {
                    videoEvents.push({
                        time: XMSoul.getFloatAttr(evNode, "time", 0.0),
                        action: XMSoul.getAttr(evNode, "action", ""),
                        val1: XMSoul.getAttr(evNode, "val1", ""),
                        val2: XMSoul.getAttr(evNode, "val2", "")
                    });
                }
            }

            isPlaying = true;
        } else {
            Logger.error('Failed loading .soulvid container: $key', "video");
            finishVideo();
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        if (!isPlaying) return;

        // Synchronize frame progress with audio time if playing, otherwise use delta time
        var playbackTime = (audioTrack != null && audioTrack.playing) ? audioTrack.time : (currentFrame / frameRate) * 1000.0;
        currentFrame += frameRate * elapsed;
        var frameInt = Std.int(currentFrame);

        if (isAtlasMode && videoSprite.frames != null) {
            if (frameInt < totalFrames) {
                videoSprite.animation.frameIndex = frameInt;
            } else {
                finishVideo();
                return;
            }
        }

        // Check Subtitles
        updateSubtitles(playbackTime);

        // Check Timed Events
        updateVideoEvents(playbackTime);

        // Skip hotkey (Escape or Accept)
        if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE) {
            finishVideo();
        }
    }

    private function updateSubtitles(curTime:Float):Void {
        var activeText = "";
        for (sub in subtitles) {
            if (curTime >= sub.time && curTime <= sub.time + 3000) { // Display for 3 seconds
                activeText = sub.text;
                break;
            }
        }
        subtitleText.text = activeText;
    }

    private function updateVideoEvents(curTime:Float):Void {
        while (videoEvents.length > 0 && videoEvents[0].time <= curTime) {
            var ev = videoEvents.shift();
            triggerVideoAction(ev.action, ev.val1, ev.val2);
        }
    }

    private function triggerVideoAction(action:String, v1:String, v2:String):Void {
        switch (action.toLowerCase()) {
            case "shakescreen" | "cameraflash":
                JuiceManager.shake(FlxG.camera, Std.parseFloat(v1), Std.parseFloat(v2));
            case "trace":
                Logger.info('[SOULVID EVENT] $v1 | $v2', "video");
        }
    }

    private function finishVideo():Void {
        if (!isPlaying) return;
        isPlaying = false;

        if (audioTrack != null) {
            audioTrack.stop();
        }

        close();
        if (onComplete != null) {
            onComplete();
        }
    }

    override public function destroy():Void {
        if (audioTrack != null) audioTrack.destroy();
        super.destroy();
    }
}