package;

import flixel.FlxGame;
import flixel.FlxState;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.events.Event;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.system.framerate.Framerate;
import soulscorch.ui.menus.states.TitleState;

class Main extends Sprite {
    var gameWidth:Int = 1280;
    var gameHeight:Int = 720;
    var initialState:Class<FlxState> = TitleState;
    var zoom:Float = -1.0;
    var framerate:Int = 120;
    var skipSplash:Bool = true;
    var startFullscreen:Bool = false;

    public static var fpsCounter:Framerate;

    public function new() {
        super();

        if (stage != null) {
            init();
        } else {
            addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        }
    }

    private function onAddedToStage(event:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        init();
    }

    private function init():Void {
        var stageWidth:Int = Lib.current.stage.stageWidth;
        var stageHeight:Int = Lib.current.stage.stageHeight;

        if (zoom == -1.0) {
            var ratioX:Float = stageWidth / gameWidth;
            var ratioY:Float = stageHeight / gameHeight;
            zoom = Math.min(ratioX, ratioY);
            gameWidth = Math.ceil(stageWidth / zoom);
            gameHeight = Math.ceil(stageHeight / zoom);
        }

        var game = new FlxGame(gameWidth, gameHeight, initialState, framerate, framerate, skipSplash, startFullscreen);
        addChild(game);

        Lib.current.stage.align = StageAlign.TOP_LEFT;
        Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;

        try {
            fpsCounter = new Framerate(10, 10, 0xFFFFFF);
            fpsCounter.visible = true;
            addChild(fpsCounter);
        } catch (e:Dynamic) {}

        try {
            var devConsole = new DevConsole();
            addChild(devConsole);
        } catch (e:Dynamic) {}
    }
}