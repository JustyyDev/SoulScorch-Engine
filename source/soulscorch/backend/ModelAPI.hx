package soulscorch.backend;

import away3d.loaders.Loader3D;
import away3d.loaders.parsers.OBJParser;
import away3d.materials.TextureMaterial;
import away3d.textures.BitmapTexture;
import away3d.events.LoaderEvent;
import openfl.net.URLRequest;
import openfl.display.BitmapData;
import soulscorch.modding.ModManager;
#if sys
import sys.FileSystem;
#end

class ModelAPI {
    // Loads an OBJ file from the mod's models folder and optionally applies a texture
    public static function loadOBJ(modelName:String, ?textureName:String):Loader3D {
        var loader = new Loader3D();
        
        #if sys
        var objPath = ModManager.getPath('models/' + modelName + '.obj');
        
        if (FileSystem.exists(objPath)) {
            // Apply a custom texture override if requested
            if (textureName != null) {
                var texPath = ModManager.getPath('images/' + textureName + '.png');
                if (FileSystem.exists(texPath)) {
                    var bmd = BitmapData.fromFile(texPath);
                    var material = new TextureMaterial(new BitmapTexture(bmd));
                    
                    // Wait for the OBJ to finish parsing before applying materials
                    loader.addEventListener(LoaderEvent.RESOURCE_COMPLETE, function(e:LoaderEvent) {
                        for (i in 0...loader.numChildren) {
                            var child = loader.getChildAt(i);
                            if (Std.isOfType(child, away3d.entities.Mesh)) {
                                var mesh:away3d.entities.Mesh = cast child;
                                mesh.material = material;
                            }
                        }
                    });
                }
            }

            // Parse the OBJ file natively using Away3D's parser
            loader.load(new URLRequest(objPath), null, null, new OBJParser(1));
            return loader;
        } else {
            if (soulscorch.ui.DevConsole.instance != null) {
                soulscorch.ui.DevConsole.instance.log('[AWAY3D ERROR] Missing OBJ model: ' + objPath);
            }
        }
        #end
        
        return loader;
    }
}