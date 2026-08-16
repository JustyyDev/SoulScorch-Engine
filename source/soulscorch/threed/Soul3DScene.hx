package soulscorch.threed;

import flixel.FlxBasic;
import openfl.Vector;

class Soul3DScene extends FlxBasic {
    public var activeCamera:Camera3D;
    public var meshes:Array<Mesh3D> = [];
    public var depthEnabled:Bool = false;
    public function new(?camera:Camera3D) { super(); activeCamera = camera == null ? new Camera3D() : camera; }
    public function addMesh(mesh:Mesh3D):Void if (mesh != null && !meshes.contains(mesh)) meshes.push(mesh);
    public function removeMesh(mesh:Mesh3D):Void meshes.remove(mesh);
    override public function draw():Void { depthEnabled = true; for (mesh in meshes) if (mesh != null && mesh.exists) mesh.render(activeCamera); depthEnabled = false; }
    override public function destroy():Void { for (mesh in meshes) if (mesh != null) mesh.destroy(); meshes = []; super.destroy(); }
}
