package soulscorch.graphics;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.textures.Texture;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.ModLoader;

#if cpp
import cpp.vm.Gc;
#end

using StringTools;

class GPUTextureManager {
    public static var cachedGraphics:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();
    public static var gpuTextures:Map<String, Texture> = new Map<String, Texture>();

    /**
     * Loads a texture directly into Stage3D GPU VRAM and disposes the RAM CPU copy.
     */
    public static function loadGPUGraphic(path:String, persist:Bool = false):Null<FlxGraphic> {
        if (path == null || path.trim().length == 0) return null;

        var resolved = AssetResolver.resolveFile(path, [".png", ".jpg", ".jpeg", ""]);
        if (resolved == null) {
            Logger.warn('Texture not found for GPU allocation: $path', "gpu");
            return null;
        }

        if (cachedGraphics.exists(resolved)) {
            var existing = cachedGraphics.get(resolved);
            if (existing != null && existing.bitmap != null) {
                return existing;
            }
        }

        var rawBitmap:BitmapData = AssetResolver.getBitmapData(resolved);
        if (rawBitmap == null) return null;

        var graphic:FlxGraphic = null;

        try {
            var stage = FlxG.stage;
            if (stage != null && stage.context3D != null) {
                // Upload directly to hardware Stage3D texture
                var texture:Texture = stage.context3D.createTexture(
                    rawBitmap.width,
                    rawBitmap.height,
                    Context3DTextureFormat.BGRA,
                    false
                );
                texture.uploadFromBitmapData(rawBitmap);

                // Create a lightweight wrapper that points to the GPU surface
                var gpuBitmap:BitmapData = BitmapData.fromTexture(texture);
                
                // Dispose CPU RAM footprint immediately
                rawBitmap.dispose();
                rawBitmap.disposeImage();

                graphic = FlxGraphic.fromBitmapData(gpuBitmap, false, resolved);
                gpuTextures.set(resolved, texture);
            } else {
                graphic = FlxGraphic.fromBitmapData(rawBitmap, false, resolved);
            }

            graphic.persist = persist;
            graphic.destroyOnNoUse = false;

            cachedGraphics.set(resolved, graphic);
            FlxG.bitmap.addGraphic(graphic);

            return graphic;
        } catch (e:Dynamic) {
            Logger.error('Failed uploading GPU texture for $resolved: $e', "gpu");
            return FlxGraphic.fromBitmapData(rawBitmap, false, resolved);
        }
    }

    public static function clearUnused():Void {
        var removedCount:Int = 0;
        for (k in cachedGraphics.keys()) {
            var gr = cachedGraphics.get(k);
            if (gr != null && gr.useCount <= 0 && !gr.persist) {
                if (gpuTextures.exists(k)) {
                    var tex = gpuTextures.get(k);
                    if (tex != null) tex.dispose();
                    gpuTextures.remove(k);
                }
                FlxG.bitmap.remove(gr);
                cachedGraphics.remove(k);
                removedCount++;
            }
        }
        if (removedCount > 0) {
            Logger.info('Flushed $removedCount unused GPU textures.', "gpu");
        }
    }

    public static function clearAll():Void {
        for (k in gpuTextures.keys()) {
            var tex = gpuTextures.get(k);
            if (tex != null) tex.dispose();
        }
        gpuTextures.clear();

        for (gr in cachedGraphics) {
            if (gr != null) {
                FlxG.bitmap.remove(gr);
            }
        }
        cachedGraphics.clear();

        #if cpp
        Gc.run(true);
        #end
    }
}