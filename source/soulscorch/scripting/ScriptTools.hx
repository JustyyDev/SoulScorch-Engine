package soulscorch.scripting;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import soulscorch.gameplay.PlayState;

class ScriptTools {
    public static function screenToWorld(screenX:Float, screenY:Float, ?camera:FlxCamera):FlxPoint {
        var target = resolveCamera(camera);
        if (target == null) return FlxPoint.get(screenX, screenY);

        var zoom = target.zoom > 0 ? target.zoom : 1.0;
        var screenCenterX = target.x + (target.width * 0.5);
        var screenCenterY = target.y + (target.height * 0.5);
        var worldCenterX = target.scroll.x + (target.width * 0.5);
        var worldCenterY = target.scroll.y + (target.height * 0.5);
        return FlxPoint.get(
            worldCenterX + ((screenX - screenCenterX) / zoom),
            worldCenterY + ((screenY - screenCenterY) / zoom)
        );
    }

    public static function worldToScreen(worldX:Float, worldY:Float, ?camera:FlxCamera):FlxPoint {
        var target = resolveCamera(camera);
        if (target == null) return FlxPoint.get(worldX, worldY);

        var zoom = target.zoom > 0 ? target.zoom : 1.0;
        var screenCenterX = target.x + (target.width * 0.5);
        var screenCenterY = target.y + (target.height * 0.5);
        var worldCenterX = target.scroll.x + (target.width * 0.5);
        var worldCenterY = target.scroll.y + (target.height * 0.5);
        return FlxPoint.get(
            screenCenterX + ((worldX - worldCenterX) * zoom),
            screenCenterY + ((worldY - worldCenterY) * zoom)
        );
    }

    public static function placeAtScreenCenter(object:FlxObject, ?camera:FlxCamera, offsetX:Float = 0, offsetY:Float = 0):Void {
        if (object == null) return;
        var target = resolveCamera(camera);
        var centerX = target != null ? target.x + target.width * 0.5 : FlxG.width * 0.5;
        var centerY = target != null ? target.y + target.height * 0.5 : FlxG.height * 0.5;
        placeAtScreen(object, centerX + offsetX, centerY + offsetY, target);
    }

    public static function placeAtScreen(object:FlxObject, screenX:Float, screenY:Float, ?camera:FlxCamera):Void {
        if (object == null) return;
        var point = screenToWorld(screenX, screenY, camera);
        object.setPosition(point.x - (object.width * 0.5), point.y - (object.height * 0.5));
        point.put();
    }

    public static function centerAtWorld(object:FlxObject, worldX:Float, worldY:Float):Void {
        if (object != null) object.setPosition(worldX - object.width * 0.5, worldY - object.height * 0.5);
    }

    public static function fitToCamera(sprite:FlxSprite, ?camera:FlxCamera, cover:Bool = true):Void {
        if (sprite == null || sprite.frameWidth <= 0 || sprite.frameHeight <= 0) return;
        var target = resolveCamera(camera);
        var viewWidth = target != null ? target.width / Math.max(target.zoom, 0.0001) : FlxG.width;
        var viewHeight = target != null ? target.height / Math.max(target.zoom, 0.0001) : FlxG.height;
        var scaleX = viewWidth / sprite.frameWidth;
        var scaleY = viewHeight / sprite.frameHeight;
        var targetScale = cover ? Math.max(scaleX, scaleY) : Math.min(scaleX, scaleY);
        sprite.scale.set(targetScale, targetScale);
        sprite.updateHitbox();
        placeAtScreenCenter(sprite, target);
    }

    public static function setCameraAnchor(worldX:Float, worldY:Float, immediate:Bool = false):Void {
        var game = PlayState.instance;
        if (game == null || game.camFollow == null) return;
        game.camFollow.setPosition(worldX, worldY);
        if (immediate && game.camFollowPos != null) game.camFollowPos.setPosition(worldX, worldY);
    }

    public static function addToStageLayer(object:FlxBasic, layerName:String):Bool {
        var game = PlayState.instance;
        if (object == null || game == null || game.currentStage == null) return false;
        var layer = game.currentStage.layers.get(layerName);
        if (layer == null) return false;
        layer.add(object);
        return true;
    }

    public static function getStageSprite(name:String):Dynamic {
        var game = PlayState.instance;
        return game != null && game.currentStage != null ? game.currentStage.namedSprites.get(name) : null;
    }

    public static function getProperty(root:Dynamic, path:String):Dynamic {
        if (root == null || path == null || path.length == 0) return null;
        var current = root;
        for (part in path.split(".")) {
            if (current == null) return null;
            current = Reflect.getProperty(current, part);
        }
        return current;
    }

    public static function setProperty(root:Dynamic, path:String, value:Dynamic):Bool {
        if (root == null || path == null || path.length == 0) return false;
        var parts = path.split(".");
        var current = root;
        for (index in 0...parts.length - 1) {
            current = Reflect.getProperty(current, parts[index]);
            if (current == null) return false;
        }
        Reflect.setProperty(current, parts[parts.length - 1], value);
        return true;
    }

    public static function after(seconds:Float, callback:Void->Void):FlxTimer {
        return new FlxTimer().start(Math.max(0, seconds), function(_) if (callback != null) callback());
    }

    public static function every(seconds:Float, callback:Int->Void, loops:Int = 0):FlxTimer {
        var count = 0;
        return new FlxTimer().start(Math.max(0.001, seconds), function(_) {
            if (callback != null) callback(count);
            count++;
        }, loops);
    }

    public static function cancelTweens(object:Dynamic):Void {
        if (object != null) FlxTween.cancelTweensOf(object);
    }

    public static function removeCamera(camera:FlxCamera, destroy:Bool = true):Void {
        if (camera != null && FlxG.cameras.list.contains(camera)) FlxG.cameras.remove(camera, destroy);
    }

    private static inline function resolveCamera(camera:FlxCamera):FlxCamera {
        return camera != null ? camera : FlxG.camera;
    }
}
