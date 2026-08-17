package soulscorch.graphics.threed;

import away3d.containers.Scene3D;
import away3d.containers.View3D;
import away3d.entities.Mesh;
import flixel.FlxG;
import openfl.Lib;
import openfl.events.Event;
import soulscorch.backend.utils.Logger;

class Away3DManager {
    public static var view:View3D;
    public static var scene(get, never):Scene3D;
    public static var isInitialized:Bool = false;
    public static var activeMeshes:Map<String, Mesh> = new Map();

    public static inline function get_scene():Scene3D {
        return view != null ? view.scene : null;
    }

    public static function init():Void {
        if (isInitialized) return;

        try {
            view = new View3D();
            view.width = FlxG.width;
            view.height = FlxG.height;
            view.antiAlias = 4;
            view.backgroundColor = 0x000000;
            view.backgroundAlpha = 0.0; // Keep transparent so 2D Flixel layers remain visible

            // Add Stage3D view behind Flixel's stage canvas
            Lib.current.stage.addChildAt(view, 0);

            Lib.current.stage.addEventListener(Event.ENTER_FRAME, onRenderTick);
            Lib.current.stage.addEventListener(Event.RESIZE, onResize);

            isInitialized = true;
            Logger.info("Away3D Stage3D viewport initialized successfully.", "3d");
        } catch (e:Dynamic) {
            Logger.error('Failed to initialize Away3D viewport: $e', "3d");
        }
    }

    public static function addMesh(id:String, mesh:Mesh):Void {
        if (view == null || mesh == null) return;
        activeMeshes.set(id, mesh);
        view.scene.addChild(mesh);
    }

    public static function getMesh(id:String):Null<Mesh> {
        return activeMeshes.get(id);
    }

    public static function removeMesh(mesh:Mesh, dispose:Bool = true):Void {
        if (view == null || mesh == null) return;

        for (key in activeMeshes.keys()) {
            if (activeMeshes.get(key) == mesh) {
                activeMeshes.remove(key);
                break;
            }
        }

        view.scene.removeChild(mesh);
        if (dispose) {
            mesh.dispose();
        }
    }

    public static function clearScene():Void {
        if (view == null) return;
        for (mesh in activeMeshes) {
            view.scene.removeChild(mesh);
            mesh.dispose();
        }
        activeMeshes.clear();
    }

    private static function onRenderTick(e:Event):Void {
        if (view != null && isInitialized) {
            view.render();
        }
    }

    private static function onResize(e:Event):Void {
        if (view != null) {
            view.width = Lib.current.stage.stageWidth;
            view.height = Lib.current.stage.stageHeight;
        }
    }

    public static function destroy():Void {
        if (!isInitialized) return;
        Lib.current.stage.removeEventListener(Event.ENTER_FRAME, onRenderTick);
        Lib.current.stage.removeEventListener(Event.RESIZE, onResize);

        clearScene();

        if (view != null) {
            if (Lib.current.stage.contains(view)) {
                Lib.current.stage.removeChild(view);
            }
            view.dispose();
            view = null;
        }

        isInitialized = false;
        Logger.info("Away3D viewport destroyed.", "3d");
    }
}