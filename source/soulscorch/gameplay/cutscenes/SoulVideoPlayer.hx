package soulscorch.gameplay.cutscenes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.ColorUtil;
import soulscorch.backend.utils.Logger;
import soulscorch.graphics.JuiceManager;

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
    private var shouldLoop:Bool = false;
    private var skipWithAccept:Bool = true;
    
    private var audioTrack:FlxSound;
    private var onComplete:Void->Void;
    private var videoPath:String;

    private var subtitles:Array<SubtitleEntry> = [];
    private var videoEvents:Array<VideoEventEntry> = [];
    private var subtitleCursor:Int = 0;
    private var eventCursor:Int = 0;
    private var subtitleVisibleUntil:Float = -1.0;
    private var lastSubtitleText:String = "";

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
            if (frameRate <= 0) frameRate = 24.0;
            var audioName = XMSoul.getAttr(access, "audio", "");
            var smoothing = XMSoul.getBoolAttr(access, "smoothing", true);
            shouldLoop = XMSoul.getBoolAttr(access, "loop", false);
            skipWithAccept = XMSoul.getBoolAttr(access, "skipWithAccept", true);
            videoSprite.antialiasing = smoothing;
            var videoScale = XMSoul.getFloatAttr(access, "scale", 1.0);
            videoSprite.scale.set(videoScale, videoScale);
            videoSprite.updateHitbox();
            videoSprite.x += XMSoul.getFloatAttr(access, "x", 0.0);
            videoSprite.y += XMSoul.getFloatAttr(access, "y", 0.0);

            if (access.has.bgColor) {
                    var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, ColorUtil.fromHexSafe(access.att.bgColor, FlxColor.BLACK));
                add(bg);
                remove(bg);
                insert(0, bg); // Put background behind video sprite
            }

            // Audio track setup
            if (audioName != "") {
                audioTrack = FlxG.sound.play(Paths.sound(audioName));
                if (audioTrack == null) audioTrack = FlxG.sound.play(Paths.music(audioName));
                if (audioTrack != null) audioTrack.volume = XMSoul.getFloatAttr(access, "volume", 1.0);
            }

            // Atlas Mode vs Loose Frames Mode
            if (access.hasNode.atlas) {
                isAtlasMode = true;
                var atlasNode = access.node.atlas;
                var atlasPath = XMSoul.getAttr(atlasNode, "path", "");
                var atlasFrames = Paths.getSparrowAtlas(atlasPath);
                if (atlasFrames != null) {
                    videoSprite.frames = atlasFrames;
                    totalFrames = videoSprite.frames.frames.length;
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
                subtitles.sort(function(a, b) {
                    if (a.time < b.time) return -1;
                    if (a.time > b.time) return 1;
                    return 0;
                });
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
                videoEvents.sort(function(a, b) {
                    if (a.time < b.time) return -1;
                    if (a.time > b.time) return 1;
                    return 0;
                });
            }

            subtitleCursor = 0;
            eventCursor = 0;
            subtitleVisibleUntil = -1.0;
            lastSubtitleText = "";

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
        if (audioTrack != null && audioTrack.playing) {
            currentFrame = (playbackTime / 1000.0) * frameRate;
        } else {
            currentFrame += frameRate * elapsed;
        }
        var frameInt = Std.int(currentFrame);

        if (isAtlasMode && videoSprite.frames != null) {
            if (frameInt < totalFrames) {
                videoSprite.animation.frameIndex = frameInt;
            } else {
                if (shouldLoop) {
                    currentFrame = 0;
                    subtitleCursor = 0;
                    eventCursor = 0;
                    lastSubtitleText = "";
                    subtitleText.text = "";
                } else {
                    finishVideo();
                    return;
                }
            }
        }

        // Check Subtitles
        updateSubtitles(playbackTime);

        // Check Timed Events
        updateVideoEvents(playbackTime);

        // Skip hotkey (Escape or Accept)
        if (skipWithAccept && (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)) {
            finishVideo();
        }
    }

    private function updateSubtitles(curTime:Float):Void {
        while (subtitleCursor < subtitles.length && curTime >= subtitles[subtitleCursor].time) {
            var sub = subtitles[subtitleCursor++];
            lastSubtitleText = sub.text;
            subtitleVisibleUntil = sub.time + 3000.0;
        }

        if (curTime > subtitleVisibleUntil) {
            if (subtitleText.text.length > 0) subtitleText.text = "";
        } else if (subtitleText.text != lastSubtitleText) {
            subtitleText.text = lastSubtitleText;
        }
    }

    private function updateVideoEvents(curTime:Float):Void {
        while (eventCursor < videoEvents.length && videoEvents[eventCursor].time <= curTime) {
            var ev = videoEvents[eventCursor++];
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
            var cb = onComplete;
            onComplete = null;
            cb();
        }
    }

    override public function destroy():Void {
        if (audioTrack != null) audioTrack.destroy();
        super.destroy();
    }
}