package soulscorch.graphics.threed;

import away3d.cameras.Camera3D;
import flixel.math.FlxMath;
import openfl.geom.Vector3D;

class Camera3DController {
    public var camera:Camera3D;
    public var targetPosition:Vector3D = new Vector3D(0, 0, -1000);
    public var targetRotation:Vector3D = new Vector3D(0, 0, 0);

    public var fov:Float = 60.0;
    public var followSpeed:Float = 4.0;
    public var isShaking:Bool = false;

    private var shakeIntensity:Float = 0.0;
    private var shakeDuration:Float = 0.0;

    public function new(?cam:Camera3D) {
        this.camera = cam != null ? cam : (Away3DManager.view != null ? Away3DManager.view.camera : new Camera3D());
        if (camera != null) {
            camera.lens.near = 20;
            camera.lens.far = 8000;
        }
    }

    public function update(elapsed:Float):Void {
        if (camera == null) return;

        // Smooth position and rotation lerping
        var lerpFactor = 1.0 - Math.exp(-followSpeed * elapsed);
        camera.x = FlxMath.lerp(camera.x, targetPosition.x, lerpFactor);
        camera.y = FlxMath.lerp(camera.y, targetPosition.y, lerpFactor);
        camera.z = FlxMath.lerp(camera.z, targetPosition.z, lerpFactor);

        camera.rotationX = FlxMath.lerp(camera.rotationX, targetRotation.x, lerpFactor);
        camera.rotationY = FlxMath.lerp(camera.rotationY, targetRotation.y, lerpFactor);
        camera.rotationZ = FlxMath.lerp(camera.rotationZ, targetRotation.z, lerpFactor);

        // Process 3D Camera Shake
        if (shakeDuration > 0) {
            shakeDuration -= elapsed;
            camera.x += (Math.random() - 0.5) * shakeIntensity * 100.0;
            camera.y += (Math.random() - 0.5) * shakeIntensity * 100.0;
            if (shakeDuration <= 0) {
                isShaking = false;
                shakeIntensity = 0.0;
            }
        }
    }

    public function shake(intensity:Float, duration:Float):Void {
        this.shakeIntensity = intensity;
        this.shakeDuration = duration;
        this.isShaking = true;
    }

    public function setPosition(x:Float, y:Float, z:Float):Void {
        targetPosition.setTo(x, y, z);
    }

    public function setRotation(pitch:Float, yaw:Float, roll:Float):Void {
        targetRotation.setTo(pitch, yaw, roll);
    }
}