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
                api_version: parsed.api_version != null ? parsed.api_version : "1.0.0",
                description: (parsed.description != null) ? parsed.description : "",
                color: (parsed.color != null) ? parsed.color : "#FFFFFF",
                icon: parsed.icon,
                global_scripts: (parsed.global_scripts != null) ? cast parsed.global_scripts : ["scripts/global.soul"],
                dependencies: (parsed.dependencies != null) ? cast parsed.dependencies : [],
                load_priority: (parsed.load_priority != null) ? parsed.load_priority : 0,
                folder: folderName
            };
        } catch (e:Dynamic) {
            Logger.warn('Failed parsing mod JSON [$folderName]: $e', "parser");
        }
        return fallback(folderName);
    }

    public static function parseXML(xmlContent:String, folderName:String = ""):SoulModData {
        if (xmlContent == null || xmlContent.trim().length == 0) return fallback(folderName);
        try {
            var rawXml = Xml.parse(xmlContent.trim());
            var rootElem:Xml = null;
            for (elem in rawXml.elements()) {
                rootElem = elem;
                break;
            }

            if (rootElem == null) return fallback(folderName);
            var xml = new Access(rootElem);

            var globalScripts:Array<String> = [];
            var deps:Array<String> = [];

            for (section in xml.elements) {
                switch (section.name.toLowerCase()) {
                    case "scripts":
                        for (scr in section.elements) {
                            if (scr.name.toLowerCase() == "script") {
                                var p = XMSoul.getAttr(scr, "path", "");
                                if (p.length > 0) globalScripts.push(p);
                            }
                        }
                    case "dependencies":
                        for (dep in section.elements) {
                            if (dep.name.toLowerCase() == "dependency") {
                                var n = XMSoul.getAttr(dep, "name", "");
                                if (n.length > 0) deps.push(n);
                            }
                        }
                }
            }

            if (globalScripts.length == 0) globalScripts.push("scripts/global.soul");

            return {
                name: XMSoul.getAttr(xml, "name", XMSoul.getAttr(xml, "title", folderName)),
                version: XMSoul.getAttr(xml, "version", "1.0.0"),
                author: XMSoul.getAttr(xml, "author", "Unknown"),
                api_version: XMSoul.getAttr(xml, "api", XMSoul.getAttr(xml, "api_version", "1.0.0")),
                description: XMSoul.getAttr(xml, "description", ""),
                color: XMSoul.getAttr(xml, "color", "#FFFFFF"),
                icon: XMSoul.getAttr(xml, "icon", "icon.png"),
                global_scripts: globalScripts,
                dependencies: deps,
                load_priority: XMSoul.getIntAttr(xml, "priority", XMSoul.getIntAttr(xml, "load_priority", 0)),
                folder: folderName
            };
        } catch (e:Dynamic) {
            Logger.warn('Failed parsing mod XML [$folderName]: $e', "parser");
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

        var xmlFiles = ["soulmod.xmsoul", "mod.xmsoul", "config.xmsoul"];
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
                return parse(File.getContent(p), folderName);
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
            global_scripts: ["scripts/global.soul"],
            dependencies: [],
            load_priority: 0,
            folder: folderName
        };
    }
}