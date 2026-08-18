package soulscorch.scripting.mod;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import hscript.Interp;
import hscript.Parser;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.utils.Logger;

class SoulGlobalScript {
    public static var stateRedirects:Map<String, String> = new Map<String, String>();
    public static var interp:Interp;
    public static var isLoaded:Bool = false;

    public static function init():Void {
        stateRedirects.clear();
        isLoaded = false;

        for (modFolder in ModLoader.activeMods) {
            var config = ModLoader.loadedModConfigs.get(modFolder);
            var scriptsToRun:Array<String> = (config != null && config.global_scripts != null) 
                ? config.global_scripts 
                : ["data/global.soul"];

            for (scriptPath in scriptsToRun) {
                var resolved = AssetResolver.resolveFile(scriptPath);
                if (resolved != null) {
                    executeScriptFile(resolved);
                }
            }
        }
    }

    private static function executeScriptFile(fullPath:String):Void {
        var rawCode = AssetResolver.getText(fullPath);
        if (rawCode == null || rawCode.length == 0) return;

        try {
            var sanitized = preprocessScript(rawCode);
            var parser = new Parser();
            parser.allowTypes = true;
            parser.allowJSON = true;
            var program = parser.parseString(sanitized);

            if (interp == null) {
                interp = new Interp();
                interp.variables.set("FlxG", FlxG);
                interp.variables.set("FlxSprite", FlxSprite);
                interp.variables.set("FlxText", FlxText);
                interp.variables.set("Paths", Paths);
                interp.variables.set("AssetHelper", AssetHelper);
                interp.variables.set("AssetResolver", AssetResolver);

                interp.variables.set("redirectState", function(originalState:String, targetScriptOrXml:String):Void {
                    if (originalState != null && targetScriptOrXml != null) {
                        stateRedirects.set(StringTools.trim(originalState).toLowerCase(), StringTools.trim(targetScriptOrXml));
                        Logger.info('State redirected: $originalState -> $targetScriptOrXml', "global-script");
                    }
                });

                interp.variables.set("trace", function(v:Dynamic):Void {
                    Logger.info(Std.string(v), "global-script");
                });
            }

            interp.execute(program);
            isLoaded = true;
            Logger.info('Executed global script: $fullPath', "global-script");
        } catch (e:Dynamic) {
            Logger.error('Failed executing script $fullPath: $e', "global-script");
        }
    }

    /**
     * Strips packages, imports, and access modifiers that break vanilla HScript parser.
     */
    private static function preprocessScript(code:String):String {
        // Strip package declarations (e.g., package;)
        var rPackage = ~/package\s+[\w\.]*;/g;
        code = rPackage.replace(code, "");

        // Strip imports (e.g., import flixel.FlxG;)
        var rImport = ~/import\s+[\w\.\*]+;/g;
        code = rImport.replace(code, "");

        // Strip access modifiers (e.g., public var, static var, override function)
        var rModifiers = ~/\b(public|private|static|override)\s+(var|function)\b/g;
        code = rModifiers.replace(code, "$2");

        return code;
    }

    public static function getRedirect(stateName:String):Null<String> {
        if (stateName == null) return null;

        var clean:String = StringTools.trim(stateName).toLowerCase();
        if (stateRedirects.exists(clean)) {
            return stateRedirects.get(clean);
        }

        var testSoul = AssetResolver.resolveFile('data/ui/$stateName.soul');
        if (testSoul != null) return stateName;

        var testXml = AssetResolver.resolveFile('data/ui/$stateName.xml');
        if (testXml != null) return stateName;

        return null;
    }
}