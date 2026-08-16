package soulscorch.modding;

import hscript.Parser;
import hscript.Interp;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import soulscorch.core.Runtime;

class ScriptCore {
    public var interp:Interp;
    public var parser:Parser;
    public var scriptName:String;
    public var active:Bool = true;

    public function new(scriptPath:String) {
        scriptName = scriptPath;
        interp = new Interp();
        parser = new Parser();
        
        parser.allowTypes = true;
        parser.allowJSON = true;
        parser.allowMetadata = true;

        exposeVariables();
        loadScript(scriptPath);
    }

    private function exposeVariables():Void {
        // Core Haxe
        interp.variables.set("Std", Std);
        interp.variables.set("Math", Math);
        interp.variables.set("StringTools", StringTools);
        #if sys interp.variables.set("Sys", Sys); #end

        // Flixel Core & Rendering
        interp.variables.set("FlxG", FlxG);
        interp.variables.set("FlxSprite", flixel.FlxSprite);
        interp.variables.set("FlxBasic", flixel.FlxBasic);
        interp.variables.set("FlxCamera", flixel.FlxCamera);
        interp.variables.set("FlxGroup", flixel.group.FlxGroup);
        interp.variables.set("FlxSpriteGroup", flixel.group.FlxSpriteGroup);
        interp.variables.set("FlxText", flixel.text.FlxText);
        
        // Flixel Math & Logic (Safe classes/functions only)
        interp.variables.set("FlxMath", flixel.math.FlxMath);
        interp.variables.set("FlxTimer", flixel.util.FlxTimer);
        interp.variables.set("FlxTween", flixel.tweens.FlxTween);
        interp.variables.set("FlxEase", flixel.tweens.FlxEase);

        // Flixel Audio
        interp.variables.set("FlxSound", flixel.sound.FlxSound);
        interp.variables.set("FlxSoundGroup", flixel.sound.FlxSoundGroup);

        // SoulScorch Backend & 3D APIs
        interp.variables.set("Runtime", soulscorch.core.Runtime);
        interp.variables.set("ModManager", soulscorch.modding.ModManager);
        interp.variables.set("NativeAPI", soulscorch.backend.NativeAPI);
        interp.variables.set("FileSystem", soulscorch.backend.FileSystemAPI);
        interp.variables.set("ShaderAPI", soulscorch.backend.ShaderAPI);
        interp.variables.set("Away3DManager", soulscorch.backend.Away3DManager);
        interp.variables.set("ModelAPI", soulscorch.backend.ModelAPI);
        interp.variables.set("UILayout", soulscorch.ui.UILayout);
        interp.variables.set("AudioSpectrum", soulscorch.media.AudioSpectrum);
        
        #if desktop
        interp.variables.set("Discord", soulscorch.backend.DiscordRPC);
        #end
        
        interp.variables.set("switchModState", function(name:String, scriptPath:String) {
            var targetPath = soulscorch.modding.ModManager.getPath('scripts/$scriptPath.hx');
            flixel.FlxG.switchState(new soulscorch.modding.ModState(name, targetPath));
        });
    }

    public function loadScript(path:String):Void {
        #if sys
        if (sys.FileSystem.exists(path)) {
            try {
                var rawCode = sys.io.File.getContent(path);
                var ast = parser.parseString(rawCode);
                interp.execute(ast);
            } catch (e:Dynamic) {
                soulscorch.ui.DevConsole.instance.log('[HSCRIPT ERROR] $scriptName: ' + e);
                active = false;
            }
        } else {
            active = false;
        }
        #end
    }

    // Call this from FlxStates to execute custom mod hooks (e.g., call("onCreate"))
    public function call(functionName:String, ?args:Array<Dynamic>):Dynamic {
        if (!active || !interp.variables.exists(functionName)) return null;
        
        try {
            var func = interp.variables.get(functionName);
            if (args == null) args = [];
            return Reflect.callMethod(null, func, args);
        } catch (e:Dynamic) {
            soulscorch.ui.DevConsole.instance.log('[HSCRIPT RUNTIME ERROR] $scriptName ($functionName): ' + e);
            return null;
        }
    }
}