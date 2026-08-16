package soulscorch.backend;

import away3d.containers.View3D;
import away3d.containers.Scene3D;
import away3d.cameras.Camera3D;
import openfl.events.Event;
import openfl.Lib;
import flixel.FlxG;

class Away3DManager {
    public static var view:View3D;
    public static var scene:Scene3D;
    public static var camera:Camera3D;
    private static var initialized:Bool = false;

    public static function init():Void {
        if (initialized) return;

        view = new View3D();
        view.backgroundColor = 0x000000;
        
        // Stage3D always renders BEHIND the OpenFL display list. 
        // We add it to index 0 so Flixel renders on top of the 3D space.
        Lib.current.stage.addChildAt(view, 0);

        scene = view.scene;
        camera = view.camera;

        Lib.current.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
        initialized = true;
    }

    private static function onEnterFrame(e:Event):Void {
        if (view != null && view.visible) {
            // Keep the 3D viewport scaled to the window size
            view.width = Lib.current.stage.stageWidth;
            view.height = Lib.current.stage.stageHeight;
            view.render();
        }
    }

    public static function destroy():Void {
        if (initialized && view != null) {
            Lib.current.stage.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
            Lib.current.stage.removeChild(view);
            view.dispose();
            view = null;
            scene = null;
            camera = null;
            initialized = false;
        }
    }
}