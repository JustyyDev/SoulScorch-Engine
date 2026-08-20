package soulscorch.scripting.mod;

import haxe.Json;
import haxe.xml.Access;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;
import soulscorch.scripting.mod.SoulModData;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class SoulModParser {
    public static function parse(jsonContent:String, folderName:String = ""):SoulModData {
        try {
            var parsed:Dynamic = Json.parse(jsonContent);
            return {
                name: (parsed.name != null) ? parsed.name : ((parsed.title != null) ? parsed.title : folderName),
                version: (parsed.version != null) ? parsed.version : "1.0.0",
                author: (parsed.author != null) ? parsed.author : "Unknown",
                api_version: parsed.api_version,
                description: (parsed.description != null) ? parsed.description : "",
                color: parsed.color,
                icon: parsed.icon,
                global_scripts: (parsed.global_scripts != null) ? cast parsed.global_scripts : ["data/global.soul"],
                dependencies: (parsed.dependencies != null) ? cast parsed.dependencies : [],
                load_priority: (parsed.load_priority != null) ? parsed.load_priority : 0,
                folder: folderName
            };
        } catch (e:Dynamic) {
            Logger.warn('Failed parsing mod metadata JSON: $e', "parser");
        }

        return fallback(folderName);
    }

    public static function parseXML(xmlContent:String, folderName:String = ""):SoulModData {
        try {
            var xml = new Access(Xml.parse(xmlContent).firstElement());
            return {
                name: XMSoul.getAttr(xml, "name", XMSoul.getAttr(xml, "title", folderName)),
                version: XMSoul.getAttr(xml, "version", "1.0.0"),
                author: XMSoul.getAttr(xml, "author", "Unknown"),
                description: XMSoul.getAttr(xml, "description", ""),
                color: XMSoul.getAttr(xml, "color", "#FFFFFF"),
                icon: XMSoul.getAttr(xml, "icon", null),
                global_scripts: ["data/global.soul"],
                dependencies: [],
                load_priority: XMSoul.getIntAttr(xml, "priority", XMSoul.getIntAttr(xml, "load_priority", 0)),
                folder: folderName
            };
        } catch (e:Dynamic) {
            Logger.warn('Failed parsing mod XML: $e', "parser");
        }
        return fallback(folderName);
    }

    #if sys
    public static function parseFolder(modPath:String, folderName:String = ""):SoulModData {
        if (folderName == "" && modPath != null) {
            var parts = modPath.replace("\\", "/").split("/");
            while (parts.length > 0 && parts[parts.length - 1] == "") parts.pop();
            if (parts.length > 0) folderName = parts[parts.length - 1];
        }

        var xmlFiles = ["mod.xmsoul", "soulmod.xmsoul", "config.xmsoul"];
        for (file in xmlFiles) {
            var p = '$modPath/$file';
            if (FileSystem.exists(p)) {
                return parseXML(File.getContent(p), folderName);
            }
        }

        var jsonFiles = ["soulmod.json", "mod.json", "_polymod_meta.json", "config.json"];
        for (file in jsonFiles) {
            var p = '$modPath/$file';
            if (FileSystem.exists(p)) {
                return parseFile(p, folderName);
            }
        }

        return fallback(folderName);
    }

    public static function parseFile(filePath:String, folderName:String = ""):SoulModData {
        if (folderName == "" && filePath != null) {
            var parts = filePath.replace("\\", "/").split("/");
            if (parts.length >= 2) {
                folderName = parts[parts.length - 2];
            }
        }

        if (FileSystem.exists(filePath)) {
            try {
                var content = File.getContent(filePath);
                if (filePath.endsWith(".xmsoul") || filePath.endsWith(".xml")) {
                    return parseXML(content, folderName);
                }
                return parse(content, folderName);
            } catch (e:Dynamic) {
                Logger.error('Failed reading mod file at $filePath: $e', "parser");
            }
        }

        return fallback(folderName);
    }
    #end

    public static function fallback(folderName:String = "unknown"):SoulModData {
        return {
            name: folderName != "" ? folderName : "Unknown Mod",
            version: "1.0.0",
            author: "Unknown",
            api_version: "1.0.0",
            description: "No description provided.",
            color: "#FFFFFF",
            icon: null,
            global_scripts: ["data/global.soul"],
            dependencies: [],
            load_priority: 0,
            folder: folderName
        };
    }
}