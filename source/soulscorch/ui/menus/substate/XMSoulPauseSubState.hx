package soulscorch.ui.menus.substate;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.xml.Access;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;
import soulscorch.gameplay.PlayState;

class XMSoulPauseSubState extends PauseSubState {
    private var pauseConfig:Access;

    override public function create():Void {
        super.create();

        // Load custom pause configuration if present
        pauseConfig = XMSoul.parse("ui/game/pauseMenu");
        if (pauseConfig != null) {
            applyCustomPauseStyling();
        }
    }

    private function applyCustomPauseStyling():Void {
        if (pauseConfig.has.bgColor) {
            // Apply custom background tint if specified in .xmsoul
            var bgTint = FlxColor.fromString(pauseConfig.att.bgColor);
            // Customize your pause layout here dynamically
        }
    }
}