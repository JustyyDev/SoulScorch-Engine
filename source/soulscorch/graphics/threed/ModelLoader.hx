package soulscorch.graphics.threed;

import away3d.entities.Mesh;
import away3d.events.Asset3DEvent;
import away3d.events.LoaderEvent;
import away3d.library.assets.Asset3DType;
import away3d.loaders.Loader3D;
import away3d.loaders.parsers.AWDParser;
import away3d.loaders.parsers.OBJParser;
import away3d.materials.TextureMaterial;
import away3d.textures.BitmapTexture;
import openfl.net.URLRequest;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;

class ModelLoader {
    /**
     * Loads a 3D model file (.obj, .awd) and binds optional texture materials.
     */
    public static function loadModel(
        modelPath:String,
        ?texturePath:String,
        ?onSuccess:Mesh->Void,
        ?onError:String->Void
    ):Loader3D {
        Away3DManager.init();

        var resolvedModel = ModLoader.getPath(modelPath);
        var loader = new Loader3D();

        loader.addEventListener(Asset3DEvent.ASSET_COMPLETE, function(event:Asset3DEvent) {
            if (event.asset.assetType == Asset3DType.MESH) {
                var mesh:Mesh = cast event.asset;

                if (texturePath != null && texturePath.length > 0) {
                    var resolvedTex = ModLoader.getPath(texturePath);
                    if (AssetResolver.exists(resolvedTex)) {
                        var bitmapData = AssetResolver.getImage(resolvedTex);
                        var texture = new BitmapTexture(bitmapData);
                        var material = new TextureMaterial(texture);
                        material.mipmap = true;
                        material.smooth = true;
                        mesh.material = material;
                    }
                }

                if (onSuccess != null) {
                    onSuccess(mesh);
                }
            }
        });

        loader.addEventListener(LoaderEvent.LOAD_ERROR, function(event:LoaderEvent) {
            Logger.error('Failed loading 3D model ($modelPath): ${event.message}', "3d");
            if (onError != null) onError(event.message);
        });

        var clean = modelPath.toLowerCase();
        if (StringTools.endsWith(clean, ".obj")) {
            loader.load(new URLRequest(resolvedModel), new OBJParser());
        } else if (StringTools.endsWith(clean, ".awd")) {
            loader.load(new URLRequest(resolvedModel), new AWDParser());
        } else {
            loader.load(new URLRequest(resolvedModel));
        }

        return loader;
    }
}