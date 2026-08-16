package soulscorch.threed;

import openfl.geom.Matrix3D;
import openfl.geom.Vector3D;
import openfl.Vector;

class Camera3D {
    public var fov:Float = 60.0;
    public var nearPlane:Float = 0.1;
    public var farPlane:Float = 1000.0;
    public var aspect:Float = 16.0 / 9.0;
    public var position:Vector3D = new Vector3D(0, 0, 5);
    public var target:Vector3D = new Vector3D();
    public var viewProjection(default, null):Matrix3D = new Matrix3D();
    public function new(?aspectRatio:Float) { if (aspectRatio != null && aspectRatio > 0) aspect = aspectRatio; updateMatrix(); }
    public function lookAt(point:Vector3D):Void { if (point != null) target = point.clone(); updateMatrix(); }
    public function setAspect(width:Float, height:Float):Void { if (height > 0) aspect = width / height; updateMatrix(); }
    public function updateMatrix():Void {
        var direction:Vector3D = target.subtract(position); if (direction.length < 0.0001) direction.z = -1;
        direction.normalize(); var up:Vector3D = new Vector3D(0, 1, 0); var right:Vector3D = direction.crossProduct(up); right.normalize(); up = right.crossProduct(direction); up.normalize();
        var raw:Vector<Float> = new Vector<Float>();
        for (value in [right.x, up.x, -direction.x, 0.0, right.y, up.y, -direction.y, 0.0, right.z, up.z, -direction.z, 0.0, -right.dotProduct(position), -up.dotProduct(position), direction.dotProduct(position), 1.0]) raw.push(value);
        viewProjection.rawData = raw; return;
    }
}
