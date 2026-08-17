package soulscorch.graphics.threed;

import haxe.Json;
import openfl.geom.Vector3D;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.ModLoader;

typedef Stage3DModelEntry = {
    var id:String;
    var model:String;
    var ?texture:String;
    var ?position:Array<Float>;
    var ?rotation:Array<Float>;
    var ?scale:Array<Float>;
}

typedef Stage3DLayout = {
    var name:String;
    var ?cameraFov:Float;
    var ?cameraPosition:Array<Float>;
    var ?models:Array<Stage3DModelEntry>;
}

class Stage3DLoader {
    public static function loadStage(jsonPath:String, targetScene:Soul3DScene, ?onComplete:Void->Void):Void {
        var resolved = ModLoader.getPath(jsonPath);
        if (!AssetResolver.exists(resolved)) {
            Logger.warn('Stage3D JSON layout not found at: $resolved', "3d");
            return;
        }

        try {
            var raw = AssetResolver.getText(resolved);
            var layout:Stage3DLayout = Json.parse(raw);

            if (layout.cameraFov != null && targetScene.camera != null) {
                targetScene.camera.fov = layout.cameraFov;
            }

            if (layout.cameraPosition != null && layout.cameraPosition.length >= 3 && targetScene.camera != null) {
                targetScene.camera.setPosition(layout.cameraPosition[0], layout.cameraPosition[1], layout.cameraPosition[2]);
            }

            if (layout.models != null) {
                for (entry in layout.models) {
                    ModelLoader.loadModel(entry.model, entry.texture, function(rawMesh) {
                        var mesh3D = new Mesh3D(entry.id, rawMesh);
                        if (entry.position != null && entry.position.length >= 3) {
                            mesh3D.position = new Vector3D(entry.position[0], entry.position[1], entry.position[2]);
                        }
                        if (entry.rotation != null && entry.rotation.length >= 3) {
                            mesh3D.rotation = new Vector3D(entry.rotation[0], entry.rotation[1], entry.rotation[2]);
                        }
                        if (entry.scale != null && entry.scale.length >= 3) {
                            mesh3D.scale = new Vector3D(entry.scale[0], entry.scale[1], entry.scale[2]);
                        }
                        targetScene.addMesh(entry.id, mesh3D);
                    });
                }
            }

            if (onComplete != null) onComplete();
        } catch (e:Dynamic) {
            Logger.error('Failed to parse Stage3D layout ($jsonPath): $e', "3d");
        }
    }
}