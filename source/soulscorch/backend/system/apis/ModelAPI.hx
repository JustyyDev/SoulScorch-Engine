package soulscorch.backend.system.apis;

import away3d.entities.Mesh;
import away3d.loaders.parsers.AWDParser;
import away3d.loaders.parsers.OBJParser;
import away3d.materials.ColorMaterial;
import away3d.materials.TextureMaterial;
import away3d.textures.BitmapTexture;
import openfl.display.BitmapData;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.graphics.threed.Away3DManager;
import soulscorch.scripting.mod.ModManager;

using StringTools;

class ModelAPI {
    public static function loadMesh(modelPath:String, ?texturePath:String):Null<Mesh> {
        if (modelPath == null || modelPath.trim().length == 0) return null;

        var resolvedModel = ModManager.getPath(modelPath);
        if (!AssetResolver.exists(resolvedModel)) {
            resolvedModel = AssetResolver.resolveFile(modelPath, [".obj", ".awd", ""]);
        }

        if (resolvedModel == null || !AssetResolver.exists(resolvedModel)) {
            Logger.warn('3D Model file not found: $modelPath', "away3d");
            return null;
        }

        var material:Dynamic = new ColorMaterial(0xFFFFFF);

        if (texturePath != null && texturePath.trim().length > 0) {
            var texPath = AssetResolver.resolveFile(texturePath, [".png", ".jpg", ""]);
            if (texPath != null && AssetResolver.exists(texPath)) {
                var graphic:Null<BitmapData> = AssetResolver.getBitmapData(texPath);
                if (graphic != null) {
                    material = new TextureMaterial(new BitmapTexture(graphic));
                }
            }
        }

        return null;
    }
}