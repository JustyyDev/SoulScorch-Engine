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

    public function new() {
        super("screenshot");
    }

    override public function update(elapsed:Float):Void {
        #if sys
        if (FlxG.keys.justPressed.F12) {
            capture();
        }
        #end
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