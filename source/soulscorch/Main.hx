package soulscorch;

import flixel.FlxGame;
import flixel.FlxG;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import openfl.display.StageAlign;
import openfl.events.Event;
import soulscorch.core.Runtime;
import soulscorch.core.GameConfig;
import soulscorch.ui.menus.TitleState;

class Main extends Sprite {
    var gameWidth:Int = 1280;
    var gameHeight:Int = 720;
    var initialState:Class<flixel.FlxState> = TitleState;
    var zoom:Float = -1.0;
    var framerate:Int = 60;
    var skipSplash:Bool = true;
    var startFullscreen:Bool = false;

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
        var config = new GameConfig(gameWidth, gameHeight, "SoulScorch Engine", framerate);
        Runtime.bootstrap(config);

        var stageWidth:Int = openfl.Lib.current.stage.stageWidth;
        var stageHeight:Int = openfl.Lib.current.stage.stageHeight;

        if (zoom == -1.0) {
            var ratioX:Float = stageWidth / gameWidth;
            var ratioY:Float = stageHeight / gameHeight;
            zoom = Math.min(ratioX, ratioY);
            gameWidth = Math.ceil(stageWidth / zoom);
            gameHeight = Math.ceil(stageHeight / zoom);
        }

        addChild(new FlxGame(gameWidth, gameHeight, initialState, framerate, framerate, skipSplash, startFullscreen));

        openfl.Lib.current.stage.align = StageAlign.TOP_LEFT;
        openfl.Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
    }
}