package soulscorch.graphics;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;

using StringTools;

class GPUAtlasFrames {
    private static var _cachedAtlasFrames:Map<String, FlxAtlasFrames> = new Map<String, FlxAtlasFrames>();

    public static function fromSparrow(imagePath:String, ?xmlPath:String):Null<FlxAtlasFrames> {
        var cleanImg = imagePath.trim();
        var cleanXml = (xmlPath != null) ? xmlPath.trim() : cleanImg;

        var cacheKey = '$cleanImg:$cleanXml';
        if (_cachedAtlasFrames.exists(cacheKey)) {
            return _cachedAtlasFrames.get(cacheKey);
        }

        var graphic:FlxGraphic = GPUTextureManager.loadGPUGraphic(cleanImg, true);
        var xmlContent:String = AssetResolver.getText(cleanXml);

        if (graphic != null && xmlContent.length > 0) {
            var frames = FlxAtlasFrames.fromSparrow(graphic, xmlContent);
            if (frames != null) {
                _cachedAtlasFrames.set(cacheKey, frames);
                return frames;
            }
        }

        Logger.warn('GPUAtlasFrames failed creating atlas for: $imagePath', "gpu");
        return null;
    }

    public static function clearCache():Void {
        _cachedAtlasFrames.clear();
    }
}