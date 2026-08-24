package soulscorch.backend.system.modules;

import flixel.FlxG;
import openfl.Lib;
import openfl.display.BitmapData;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.system.NotificationManager;
import soulscorch.backend.system.modules.Module.ModuleBase;
import soulscorch.backend.utils.GameTime;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class ScreenshotModule extends ModuleBase {
    public var screenshotKey:String = "F12";
    public var saveDirectory:String = "screenshots";
    public var soundEffect:String = "scrollMenu";
    public var soundVolume:Float = 0.7;

    private var captureCooldown:Float = 0.35;
    private var captureCooldownTimer:Float = 0.0;

    public function new() {
        super("screenshot");
    }

    override public function update(elapsed:Float):Void {
        if (captureCooldownTimer > 0) {
            captureCooldownTimer -= elapsed;
        }

        #if sys
        if (captureCooldownTimer <= 0 && isCaptureKeyJustPressed()) {
            capture();
            captureCooldownTimer = captureCooldown;
        }
        #end
    }

    private function isCaptureKeyJustPressed():Bool {
        var key = screenshotKey != null ? screenshotKey.toUpperCase() : "F12";
        return switch (key) {
            case "F2": FlxG.keys.justPressed.F2;
            case "F3": FlxG.keys.justPressed.F3;
            case "F4": FlxG.keys.justPressed.F4;
            case "F5": FlxG.keys.justPressed.F5;
            case "F6": FlxG.keys.justPressed.F6;
            case "F7": FlxG.keys.justPressed.F7;
            case "F8": FlxG.keys.justPressed.F8;
            case "F9": FlxG.keys.justPressed.F9;
            case "F10": FlxG.keys.justPressed.F10;
            case "F11": FlxG.keys.justPressed.F11;
            case "PRINTSCREEN", "PRTSC": FlxG.keys.justPressed.PRINTSCREEN;
            default: FlxG.keys.justPressed.F12;
        }
    }

    public function capture():Void {
        #if sys
        try {
            var dateStr = StringTools.replace(StringTools.replace(GameTime.dateString(), ":", "-"), " ", "_");
            if (!FileSystem.exists(saveDirectory)) {
                FileSystem.createDirectory(saveDirectory);
            }

            var filePath = '$saveDirectory/SoulScorch_$dateStr.png';
            var stage = Lib.current.stage;
            
            if (stage == null || stage.stageWidth <= 0 || stage.stageHeight <= 0) {
                Logger.error("[SCREENSHOT] Invalid stage dimensions for capture.", "screenshot");
                return;
            }

            var bitmap = new BitmapData(stage.stageWidth, stage.stageHeight, true, 0x00000000);
            bitmap.draw(stage);

            var bytes = bitmap.encode(bitmap.rect, new openfl.display.PNGEncoderOptions(true));
            File.saveBytes(filePath, bytes);
            bitmap.dispose();

            if (soundEffect != null && soundEffect.length > 0) {
                AssetHelper.playSoundSafely(soundEffect, soundVolume);
            }

            if (NotificationManager.instance != null) {
                NotificationManager.instance.notify("Screenshot Saved", 'Successfully saved to $filePath');
            }

            Logger.info('[SCREENSHOT] High-resolution capture saved: $filePath', "screenshot");
        } catch (e:Dynamic) {
            Logger.error('[SCREENSHOT ERROR] Failed to capture screenshot: $e', "screenshot");
        }
        #end
    }
}