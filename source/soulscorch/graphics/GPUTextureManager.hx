package soulscorch.graphics;

import openfl.display.BitmapData;
import openfl.display3D.textures.Texture;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModLoader;
import soulscorch.core.Logger;

class GPUTextureManager {
    static var trackedGraphics:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();

    public static function loadGraphic(path:String, purgeRAM:Bool = true):FlxGraphic {
        var resolvedPath = ModLoader.getPath(path);

        if (trackedGraphics.exists(resolvedPath)) {
            return trackedGraphics.get(resolvedPath);
        }

        if (!AssetResolver.exists(resolvedPath)) {
            Logger.warn("gpu", 'Texture not found: $resolvedPath');
            return null;
        }

        var rawBitmap = BitmapData.fromFile(resolvedPath);
        if (rawBitmap == null) return null;

        var graphic:FlxGraphic = FlxGraphic.fromBitmapData(rawBitmap, false, resolvedPath);
        graphic.persist = true;
        graphic.destroyOnNoUse = false;

        if (purgeRAM) {
            // Force hardware texture creation on GPU
            @:privateAccess
            if (FlxG.stage.context3D != null) {
                var texture:Texture = FlxG.stage.context3D.createTexture(
                    rawBitmap.width,
                    rawBitmap.height,
                    openfl.display3D.Context3DTextureFormat.BGRA,
                    false
                );
                texture.uploadFromBitmapData(rawBitmap);
                rawBitmap.dispose();
                rawBitmap.disposeImage();
            }
        }

        trackedGraphics.set(resolvedPath, graphic);
        return graphic;
    }

    public static function clearUnused():Void {
        for (key in trackedGraphics.keys()) {
            var g = trackedGraphics.get(key);
            if (g != null && g.useCount <= 0) {
                g.destroy();
                trackedGraphics.remove(key);
            }
        }
    }

    public static function clearAll():Void {
        for (g in trackedGraphics) {
            if (g != null) g.destroy();
        }
        trackedGraphics.clear();
    }
}