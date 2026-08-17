package soulscorch.scripting.mod;

import haxe.Json;
import soulscorch.backend.system.engine.DevConsole;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.SoulModData;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class SoulModParser {
    public static function parse(modDirectory:String):SoulModData {
        var path = 'mods/$modDirectory/soulmod.json';  
        var metaPath = 'mods/$modDirectory/mod.json';

        #if sys
        var targetFile = FileSystem.exists(path) ? path : (FileSystem.exists(metaPath) ? metaPath : null);
        if (targetFile != null) {
            try {
                var rawJson = File.getContent(targetFile);  
                var data:Dynamic = Json.parse(rawJson);  

                return {
                    name: data.name != null ? data.name : modDirectory,  
                    version: data.version != null ? data.version : "1.0.0",  
                    api_version: data.api_version != null ? data.api_version : (data.api != null ? data.api : "0.1.0"),  
                    description: data.description != null ? data.description : "A standard SoulScorch mod.",  
                    color: data.color != null ? data.color : "#FFFFFF",  
                    global_scripts: data.global_scripts != null ? data.global_scripts : [],  
                    flags: data.flags != null ? data.flags : [],  
                    load_priority: data.load_priority != null ? data.load_priority : 0,  
                    restart_required: data.restart_required != null ? data.restart_required : false,
                    dependencies: data.dependencies != null ? data.dependencies : [],
                    author: data.author != null ? data.author : "Unknown"
                };
            } catch (e:Dynamic) {
                Logger.error('Failed parsing mod metadata in $targetFile: $e', "mods");
                if (DevConsole.instance != null) {
                    DevConsole.instance.log('[ERROR] Failed to parse $targetFile: ' + Std.string(e));  
                }
            }
        }
        #end

        return {
            name: modDirectory,  
            version: "1.0.0",  
            api_version: "0.1.0",  
            description: "A standard SoulScorch mod.",  
            color: "#FFFFFF",  
            global_scripts: [],  
            flags: [],  
            load_priority: 0,  
            restart_required: false,
            dependencies: [],
            author: "Unknown"
        };
    }
}