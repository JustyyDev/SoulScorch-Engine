package soulscorch.graphics.threed;

import away3d.cameras.Camera3D as AwayCamera;
import away3d.cameras.lenses.PerspectiveLens;
import openfl.geom.Vector3D;

class Camera3D {
    public var rawCamera:AwayCamera;
    public var fov(get, set):Float;
    public var position(get, set):Vector3D;
    public var rotation(get, set):Vector3D;

    public function new(fov:Float = 60.0, near:Float = 20.0, far:Float = 8000.0) {
        rawCamera = new AwayCamera();
        var lens = new PerspectiveLens(fov);
        lens.near = near;
        lens.far = far;
        rawCamera.lens = lens;
        rawCamera.z = -1000;
    }

    private inline function get_fov():Float {
        return (Std.isOfType(rawCamera.lens, PerspectiveLens)) ? cast(rawCamera.lens, PerspectiveLens).fieldOfView : 60.0;
    }

    private inline function set_fov(val:Float):Float {
        if (Std.isOfType(rawCamera.lens, PerspectiveLens)) {
            cast(rawCamera.lens, PerspectiveLens).fieldOfView = val;
        }
        return val;
    }

    private inline function get_position():Vector3D {
        return rawCamera.position;
    }

    private inline function set_position(val:Vector3D):Vector3D {
        rawCamera.position = val;
        return val;
    }

    private inline function get_rotation():Vector3D {
        return new Vector3D(rawCamera.rotationX, rawCamera.rotationY, rawCamera.rotationZ);
    }

    private inline function set_rotation(val:Vector3D):Vector3D {
        rawCamera.rotationX = val.x;
        rawCamera.rotationY = val.y;
        rawCamera.rotationZ = val.z;
        return val;
    }

    public function lookAt(target:Vector3D, ?upAxis:Vector3D):Void {
        rawCamera.lookAt(target, upAxis);
    }
}