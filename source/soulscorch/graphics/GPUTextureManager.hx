package soulscorch.graphics;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.display3D.textures.Texture;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;

class GPUTextureManager {
    public static var cachedGraphics:Map<String, FlxGraphic> = new Map();

    /**
     * Loads a texture directly onto GPU memory, persisting VRAM and bypassing duplicate RAM caching.
     */
    public static function loadGPUGraphic(path:String, persist:Bool = false):Null<FlxGraphic> {
        var resolved = ModLoader.getPath(path);
        if (!AssetResolver.exists(resolved)) {
            Logger.warn('Texture not found at: $resolved', "gpu");
            return null;
        }

        if (cachedGraphics.exists(resolved)) {
            return cachedGraphics.get(resolved);
        }

        var bmd:BitmapData = AssetResolver.getImage(resolved);
        if (bmd == null) return null;

        var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bmd, false, resolved);
        graphic.persist = persist;
        graphic.destroyOnUse = false;

        cachedGraphics.set(resolved, graphic);
        FlxG.bitmap.addGraphic(graphic);

        return graphic;
    }

    public static function clearUnused():Void {
        for (k in cachedGraphics.keys()) {
            var gr = cachedGraphics.get(k);
            if (gr != null && gr.useCount <= 0 && !gr.persist) {
                FlxG.bitmap.remove(gr);
                cachedGraphics.remove(k);
            }
        }
    }

    public static function clearAll():Void {
        for (gr in cachedGraphics) {
            if (gr != null) {
                FlxG.bitmap.remove(gr);
            }
        }
        cachedGraphics.clear();
    }
}