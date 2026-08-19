package soulscorch.backend.system.engine;

import flixel.FlxG;
import soulscorch.backend.utils.EngineUtils;
import soulscorch.backend.utils.Logger;

class GameConfig {
    public var downscroll:Bool = false;
    public var middlescroll:Bool = false;
    public var ghostTapping:Bool = true;
    public var framerate:Int = 120;
    public var flashingLights:Bool = true;
    public var antialiasing:Bool = true;
    public var autoGC:Bool = true;
    public var offset:Float = 0.0;
    public var masterVolume:Float = 1.0;
    public var instrumentalVolume:Float = 1.0;
    public var vocalVolume:Float = 1.0;
    public var shadersEnabled:Bool = true;
    public var lowQualityShaders:Bool = false;

    public function new() {
        load();
    }

    public function load():Void {
        try {
            if (FlxG.save != null && FlxG.save.data != null) {
                if (FlxG.save.data.downscroll != null) downscroll = FlxG.save.data.downscroll;
                if (FlxG.save.data.middlescroll != null) middlescroll = FlxG.save.data.middlescroll;
                if (FlxG.save.data.ghostTapping != null) ghostTapping = FlxG.save.data.ghostTapping;
                if (FlxG.save.data.framerate != null) framerate = FlxG.save.data.framerate;
                if (FlxG.save.data.flashingLights != null) flashingLights = FlxG.save.data.flashingLights;
                if (FlxG.save.data.antialiasing != null) antialiasing = FlxG.save.data.antialiasing;
                if (FlxG.save.data.autoGC != null) autoGC = FlxG.save.data.autoGC;
                if (FlxG.save.data.offset != null) offset = FlxG.save.data.offset;
                if (FlxG.save.data.masterVolume != null) masterVolume = FlxG.save.data.masterVolume;
                if (FlxG.save.data.instrumentalVolume != null) instrumentalVolume = FlxG.save.data.instrumentalVolume;
                if (FlxG.save.data.vocalVolume != null) vocalVolume = FlxG.save.data.vocalVolume;
                if (FlxG.save.data.shadersEnabled != null) shadersEnabled = FlxG.save.data.shadersEnabled;
                if (FlxG.save.data.lowQualityShaders != null) lowQualityShaders = FlxG.save.data.lowQualityShaders;
            }

            EngineUtils.setFramerate(framerate);
            applyAudioPreferences();
            
            Logger.info("Game configuration loaded successfully.", "config");
        } catch (e:Dynamic) {
            Logger.error('Failed loading configuration: $e', "config");
        }
    }

    public function save():Void {
        try {
            if (FlxG.save != null && FlxG.save.data != null) {
                FlxG.save.data.downscroll = downscroll;
                FlxG.save.data.middlescroll = middlescroll;
                FlxG.save.data.ghostTapping = ghostTapping;
                FlxG.save.data.framerate = framerate;
                FlxG.save.data.flashingLights = flashingLights;
                FlxG.save.data.antialiasing = antialiasing;
                FlxG.save.data.autoGC = autoGC;
                FlxG.save.data.offset = offset;
                FlxG.save.data.masterVolume = masterVolume;
                FlxG.save.data.instrumentalVolume = instrumentalVolume;
                FlxG.save.data.vocalVolume = vocalVolume;
                FlxG.save.data.shadersEnabled = shadersEnabled;
                FlxG.save.data.lowQualityShaders = lowQualityShaders;
                FlxG.save.flush();
            }

            EngineUtils.setFramerate(framerate);
            applyAudioPreferences();

            Logger.info("Game configuration saved to disk.", "config");
        } catch (e:Dynamic) {
            Logger.error('Failed saving configuration: $e', "config");
        }
    }

    public function resetToDefaults():Void {
        downscroll = false;
        middlescroll = false;
        ghostTapping = true;
        framerate = 120;
        flashingLights = true;
        antialiasing = true;
        autoGC = true;
        offset = 0.0;
        masterVolume = 1.0;
        instrumentalVolume = 1.0;
        vocalVolume = 1.0;
        shadersEnabled = true;
        lowQualityShaders = false;
        save();
    }

    private function applyAudioPreferences():Void {
        if (FlxG.sound != null) {
            FlxG.sound.volume = masterVolume;
        }
    }
}