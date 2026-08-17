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
            var directory = "screenshots";
            if (!FileSystem.exists(directory)) {
                FileSystem.createDirectory(directory);
            }

            var filePath = '$directory/SoulScorch_$dateStr.png';
            var stage = Lib.current.stage;
            var bitmap = new BitmapData(stage.stageWidth, stage.stageHeight, true, 0x00000000);
            bitmap.draw(stage);

            var bytes = bitmap.encode(bitmap.rect, new openfl.display.PNGEncoderOptions());
            File.saveBytes(filePath, bytes);
            bitmap.dispose();

            AssetHelper.playSoundSafely("scrollMenu", 0.7);
            if (NotificationManager.instance != null) {
                NotificationManager.instance.notify("Screenshot Saved", 'Saved to $filePath');
            }
            Logger.info('Screenshot captured: $filePath');
        } catch (e:Dynamic) {
            Logger.error('Failed to capture screenshot: $e');
        }
        #end
    }
}