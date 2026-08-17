package soulscorch.graphics.threed;

import away3d.containers.Scene3D;
import away3d.containers.View3D;
import openfl.geom.Vector3D;
import soulscorch.backend.utils.Logger;

class Soul3DScene {
    public var view:View3D;
    public var camera:Camera3DController;
    public var meshes:Map<String, Mesh3D> = new Map();

    public function new() {
        Away3DManager.init();
        this.view = Away3DManager.view;
        this.camera = new Camera3DController(view != null ? view.camera : null);
    }

    public function addMesh(id:String, mesh:Mesh3D):Void {
        if (mesh == null || mesh.rawMesh == null) return;
        meshes.set(id, mesh);
        if (view != null && view.scene != null) {
            view.scene.addChild(mesh.rawMesh);
        }
    }

    public function getMesh(id:String):Null<Mesh3D> {
        return meshes.get(id);
    }

    public function removeMesh(id:String):Void {
        var m = meshes.get(id);
        if (m != null) {
            m.destroy();
            meshes.remove(id);
        }
    }

    public function update(elapsed:Float):Void {
        if (camera != null) {
            camera.update(elapsed);
        }
    }

    public function clear():Void {
        for (k in meshes.keys()) {
            removeMesh(k);
        }
        meshes.clear();
    }

    public function destroy():Void {
        clear();
        camera = null;
        view = null;
    }
}