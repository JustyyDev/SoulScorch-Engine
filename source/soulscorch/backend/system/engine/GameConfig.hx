package soulscorch.backend.system.engine;

import flixel.FlxG;
import soulscorch.backend.system.SaveData;
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
    public var defaultNoteSkin:String = "default";
    public var cameraZoomOnBeat:Bool = true;
    public var botplay:Bool = false;
    public var noteSplash:Bool = true;
    public var exportReplayMp4:Bool = false;

    public function new() {
        load();
    }

    public function load():Void {
        try {
            var saveInst = SaveData.instance;

            downscroll = saveInst.getBool("downscroll", false);
            middlescroll = saveInst.getBool("middlescroll", false);
            ghostTapping = saveInst.getBool("ghostTapping", true);
            framerate = saveInst.getInt("framerate", 120);
            flashingLights = saveInst.getBool("flashingLights", true);
            antialiasing = saveInst.getBool("antialiasing", true);
            autoGC = saveInst.getBool("autoGC", true);
            offset = saveInst.getFloat("noteOffset", saveInst.getFloat("offset", 0.0));
            masterVolume = saveInst.getFloat("masterVolume", 1.0);
            instrumentalVolume = saveInst.getFloat("instrumentalVolume", 1.0);
            vocalVolume = saveInst.getFloat("vocalVolume", 1.0);
            shadersEnabled = saveInst.getBool("shadersEnabled", true);
            lowQualityShaders = saveInst.getBool("lowQualityShaders", false);
            defaultNoteSkin = saveInst.getString("noteSkin", "default");
            cameraZoomOnBeat = saveInst.getBool("cameraZoomOnBeat", true);
            botplay = saveInst.getBool("botplay", false);
            noteSplash = saveInst.getBool("noteSplash", true);
            exportReplayMp4 = saveInst.getBool("exportReplayMp4", false);

            EngineUtils.setFramerate(framerate);
            applyAudioPreferences();
            
            Logger.info("Game configuration synchronized with SaveData successfully.", "config");
        } catch (e:Dynamic) {
            Logger.error('Failed loading configuration: $e', "config");
        }
    }

    public function save():Void {
        try {
            var saveInst = SaveData.instance;

            saveInst.setSetting("downscroll", downscroll, false);
            saveInst.setSetting("middlescroll", middlescroll, false);
            saveInst.setSetting("ghostTapping", ghostTapping, false);
            saveInst.setSetting("framerate", framerate, false);
            saveInst.setSetting("flashingLights", flashingLights, false);
            saveInst.setSetting("antialiasing", antialiasing, false);
            saveInst.setSetting("autoGC", autoGC, false);
            saveInst.setSetting("noteOffset", offset, false);
            saveInst.setSetting("masterVolume", masterVolume, false);
            saveInst.setSetting("instrumentalVolume", instrumentalVolume, false);
            saveInst.setSetting("vocalVolume", vocalVolume, false);
            saveInst.setSetting("shadersEnabled", shadersEnabled, false);
            saveInst.setSetting("lowQualityShaders", lowQualityShaders, false);
            saveInst.setSetting("noteSkin", defaultNoteSkin, false);
            saveInst.setSetting("cameraZoomOnBeat", cameraZoomOnBeat, false);
            saveInst.setSetting("botplay", botplay, false);
            saveInst.setSetting("noteSplash", noteSplash, false);
            saveInst.setSetting("exportReplayMp4", exportReplayMp4, false);

            saveInst.persist();

            EngineUtils.setFramerate(framerate);
            applyAudioPreferences();

            Logger.info("Game configuration persisted to disk.", "config");
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
        defaultNoteSkin = "default";
        cameraZoomOnBeat = true;
        botplay = false;
        noteSplash = true;
        exportReplayMp4 = false;
        save();
    }

    private function applyAudioPreferences():Void {
        if (FlxG.sound != null) {
            FlxG.sound.volume = masterVolume;
        }
    }
}