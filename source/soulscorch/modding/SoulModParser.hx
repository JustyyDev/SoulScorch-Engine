package soulscorch.modding;

import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef SoulModData = {
    var name:String;
    var version:String;
    var api_version:String;
    var description:String;
    var color:String;
    var global_scripts:Array<String>;
    var flags:Array<String>;
    var load_priority:Int;
}

class SoulModParser {
    public static function parse(modDirectory:String):SoulModData {
        var path = 'mods/$modDirectory/soulmod.json';
        
        #if sys
        if (FileSystem.exists(path)) {
            var rawJson = File.getContent(path);
            try {
                var data:SoulModData = Json.parse(rawJson);
                return data;
            } catch (e:Dynamic) {
                if (soulscorch.ui.DevConsole.instance != null) {
                    soulscorch.ui.DevConsole.instance.log('[ERROR] Failed to parse $path: ' + e);
                }
            }
        }
        #end
        
        // Return a safe default if the file is missing or broken
        return {
            name: modDirectory,
            version: "1.0.0",
            api_version: "0.1.0",
            description: "A standard SoulScorch mod.",
            color: "#FFFFFF",
            global_scripts: [],
            flags: [],
            load_priority: 0
        };
    }
}