package soulscorch.backend.system.apis;

import away3d.entities.Mesh;
import away3d.events.LoaderEvent;
import away3d.loaders.Loader3D;
import away3d.loaders.parsers.OBJParser;
import away3d.materials.TextureMaterial;
import away3d.textures.BitmapTexture;
import openfl.display.BitmapData;
import openfl.net.URLRequest;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;

#if sys
import sys.FileSystem;
#end

class ModelAPI {
    /**
     * Loads a 3D Wavefront (.obj) model from mod/asset directories and applies materials.
     */
    public static function loadOBJ(modelName:String, ?textureName:String, ?onComplete:Loader3D->Void):Loader3D {
        var loader = new Loader3D();

        #if sys
        var objPath = ModLoader.getPath('models/$modelName.obj');
        if (objPath == null || !FileSystem.exists(objPath)) {
            objPath = ModLoader.getPath('assets/models/$modelName.obj');
        }

        if (objPath != null && FileSystem.exists(objPath)) {
            var material:TextureMaterial = null;

            if (textureName != null) {
                var texPath = Paths.image('models/$textureName');
                if (!AssetResolver.exists(texPath)) {
                    texPath = Paths.image(textureName);
                }

                if (AssetResolver.exists(texPath)) {
                    var graphic = AssetResolver.getImage(texPath);
                    if (graphic != null) {
                        material = new TextureMaterial(new BitmapTexture(graphic.bitmap));
                    }
                }
            }

            loader.addEventListener(LoaderEvent.RESOURCE_COMPLETE, function(e:LoaderEvent) {
                if (material != null) {
                    for (i in 0...loader.numChildren) {
                        var child = loader.getChildAt(i);
                        if (Std.isOfType(child, Mesh)) {
                            var mesh:Mesh = cast child;
                            mesh.material = material;
                        }
                    }
                }
                if (onComplete != null) {
                    onComplete(loader);
                }
            });

            loader.addEventListener(LoaderEvent.LOAD_ERROR, function(e:LoaderEvent) {
                Logger.error('Failed parsing OBJ model at $objPath: ${e.message}');
            });

            loader.load(new URLRequest(objPath), null, null, new OBJParser(1));
            return loader;
        } else {
            Logger.warn('Missing 3D OBJ model asset: $modelName ($objPath)');
        }
        #end

        return loader;
    }
}