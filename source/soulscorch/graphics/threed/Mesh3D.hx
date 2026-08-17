package soulscorch.graphics.threed;

import away3d.entities.Mesh;
import away3d.materials.TextureMaterial;
import away3d.textures.BitmapTexture;
import flixel.math.FlxMath;
import openfl.display.BitmapData;
import openfl.geom.Vector3D;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.scripting.ModLoader;

class Mesh3D {
    public var id:String;
    public var rawMesh:Mesh;
    public var material:TextureMaterial;

    public var position(get, set):Vector3D;
    public var rotation(get, set):Vector3D;
    public var scale(get, set):Vector3D;

    public function new(id:String, mesh:Mesh) {
        this.id = id;
        this.rawMesh = mesh;
        if (mesh != null && mesh.material != null && Std.isOfType(mesh.material, TextureMaterial)) {
            this.material = cast mesh.material;
        }
    }

    public function setTexture(path:String):Void {
        var resolved = ModLoader.getPath(path);
        if (AssetResolver.exists(resolved)) {
            var bmd:BitmapData = AssetResolver.getImage(resolved);
            if (material == null) {
                material = new TextureMaterial(new BitmapTexture(bmd));
                material.smooth = true;
                material.mipmap = true;
                rawMesh.material = material;
            } else {
                material.texture = new BitmapTexture(bmd);
            }
        }
    }

    private inline function get_position():Vector3D return rawMesh != null ? rawMesh.position : new Vector3D();
    private inline function set_position(v:Vector3D):Vector3D {
        if (rawMesh != null) rawMesh.position = v;
        return v;
    }

    private inline function get_rotation():Vector3D return rawMesh != null ? new Vector3D(rawMesh.rotationX, rawMesh.rotationY, rawMesh.rotationZ) : new Vector3D();
    private inline function set_rotation(v:Vector3D):Vector3D {
        if (rawMesh != null) {
            rawMesh.rotationX = v.x;
            rawMesh.rotationY = v.y;
            rawMesh.rotationZ = v.z;
        }
        return v;
    }

    private inline function get_scale():Vector3D return rawMesh != null ? new Vector3D(rawMesh.scaleX, rawMesh.scaleY, rawMesh.scaleZ) : new Vector3D(1, 1, 1);
    private inline function set_scale(v:Vector3D):Vector3D {
        if (rawMesh != null) {
            rawMesh.scaleX = v.x;
            rawMesh.scaleY = v.y;
            rawMesh.scaleZ = v.z;
        }
        return v;
    }

    public function destroy():Void {
        if (rawMesh != null) {
            if (rawMesh.parent != null) rawMesh.parent.removeChild(rawMesh);
            rawMesh.dispose();
            rawMesh = null;
        }
        material = null;
    }
}