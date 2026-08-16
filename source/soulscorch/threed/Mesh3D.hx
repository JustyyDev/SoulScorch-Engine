package soulscorch.threed;

import openfl.geom.Vector3D;
import flixel.FlxBasic;

class Mesh3D extends FlxBasic {
    public var vertices:Array<Float> = [];
    public var normals:Array<Float> = [];
    public var uvs:Array<Float> = [];
    public var indices:Array<Int> = [];
    public var position:Vector3D = new Vector3D();
    public var rotation:Vector3D = new Vector3D();
    public var scale:Vector3D = new Vector3D(1, 1, 1);
    public var diffusePath:String = "";
    public var ambient:Float = 0.25;
    public var fogDensity:Float = 0.0;
    public function new() super();
    public function setGeometry(vertexData:Array<Float>, indexData:Array<Int>, ?normalData:Array<Float>, ?uvData:Array<Float>):Void { vertices = vertexData == null ? [] : vertexData; indices = indexData == null ? [] : indexData; normals = normalData == null ? [] : normalData; uvs = uvData == null ? [] : uvData; }
    public function vertexCount():Int return Std.int(vertices.length / 3);
    public function triangleCount():Int return Std.int(indices.length / 3);
    public function render(camera:Camera3D):Void { if (camera == null || vertices.length == 0) return; }
    override public function destroy():Void { vertices = []; normals = []; uvs = []; indices = []; super.destroy(); }
}
