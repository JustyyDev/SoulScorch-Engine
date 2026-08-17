package soulscorch.modding;

#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.Json;
import StringTools;

typedef ModMetadata = {
    var id:String;
    var name:String;
    var description:String;
    var version:String;
    var api:String;
}

class ModLoader {
    public static var activeMods:Array<ModMetadata> = [];
    public static var modDirectories:Array<String> = [];

    private static function getActiveModDirectories():Array<String> {
        var roots:Array<String> = [];
        var seen:Map<String, Bool> = new Map();

        function addRoot(root:String):Void {
            if (root == null || root.length == 0) return;
            var clean = StringTools.replace(root, "\\", "/");
            if (!seen.exists(clean)) {
                roots.push(clean);
                seen.set(clean, true);
            }
        }

        if (ModManager.activeMods != null) {
            if (ModManager.activeMods.length > 0) {
                for (modName in ModManager.activeMods) {
                    addRoot('mods/$modName');
                }
                return roots;
            }

            // ModManager explicitly disabled all mods.
            if (ModManager.selectedMod == null && ModManager.allMods != null) {
                return [];
            }
        }

        for (dir in modDirectories) {
            addRoot(dir);
        }

        return roots;
    }

    public function new() {}

    public function scan():Void {
        #if sys
        var modsPath = "mods/";
        if (!FileSystem.exists(modsPath)) {
            FileSystem.createDirectory(modsPath);
            return;
        }

        var directories = FileSystem.readDirectory(modsPath);
        for (dir in directories) {
            var fullPath = modsPath + dir;
            if (FileSystem.isDirectory(fullPath)) {
                var metaPath = fullPath + "/mod.json";
                if (FileSystem.exists(metaPath)) {
                    var raw = File.getContent(metaPath);
                    var meta:ModMetadata = cast Json.parse(raw);
                    activeMods.push(meta);
                    modDirectories.push(fullPath);
                }
            }
        }
        #end
    }

    private static function normalizeAssetPath(assetPath:String):String {
        if (assetPath == null) {
            return "";
        }

        var normalized = StringTools.replace(StringTools.trim(assetPath), "\\", "/");
        while (normalized.indexOf("./") == 0) {
            normalized = normalized.substr(2);
        }

        if (normalized.length == 0 || normalized == "/") {
            return "";
        }

        if (normalized.indexOf("assets/preload/") == 0) {
            normalized = "assets/" + normalized.substr("assets/preload/".length);
        } else if (normalized.indexOf("assets/") != 0 && normalized.indexOf("mods/") != 0 && normalized.indexOf("http://") != 0 && normalized.indexOf("https://") != 0) {
            normalized = "assets/" + normalized;
        }

        return normalized;
    }

    private static function getAssetCandidates(assetPath:String):Array<String> {
        var normalized = normalizeAssetPath(assetPath);
        if (normalized.length == 0) return [];
        var candidates:Array<String> = [];
        var seen:Map<String, Bool> = new Map();

        function addCandidate(candidate:String):Void {
            if (candidate == null || candidate.length == 0) return;
            var clean = StringTools.replace(candidate, "\\", "/");
            if (!seen.exists(clean)) {
                candidates.push(clean);
                seen.set(clean, true);
            }
        }

        addCandidate(normalized);

        if (normalized.indexOf("assets/") == 0) {
            addCandidate("assets/preload/" + normalized.substr("assets/".length));
        } else {
            addCandidate("assets/" + normalized);
            addCandidate("assets/preload/" + normalized);
        }

        if (normalized.indexOf("assets/preload/") == 0) {
            addCandidate("assets/" + normalized.substr("assets/preload/".length));
        }

        return candidates;
    }

    private static function getModCandidates(assetPath:String):Array<String> {
        var normalized = normalizeAssetPath(assetPath);
        if (normalized.length == 0) return [];
        var relative = normalized;

        if (relative.indexOf("assets/") == 0) {
            relative = relative.substr("assets/".length);
        }

        var candidates:Array<String> = [];
        var seen:Map<String, Bool> = new Map();

        function addCandidate(candidate:String):Void {
            if (candidate == null || candidate.length == 0) return;
            var clean = StringTools.replace(candidate, "\\", "/");
            if (!seen.exists(clean)) {
                candidates.push(clean);
                seen.set(clean, true);
            }
        }

        addCandidate(relative);
        addCandidate("assets/" + relative);
        addCandidate("assets/preload/" + relative);
        addCandidate("mods/" + relative);
        addCandidate("mods/assets/" + relative);
        addCandidate("mods/assets/preload/" + relative);

        return candidates;
    }

    public function resolveAsset(path:String):Null<String> {
        if (path == null || StringTools.trim(path).length == 0) {
            return null;
        }
        #if sys
        var normalized = normalizeAssetPath(path);
        if (normalized.length == 0) {
            return null;
        }
        for (candidate in getAssetCandidates(normalized)) {
            if (FileSystem.exists(candidate)) {
                return candidate;
            }
        }

        var roots = getActiveModDirectories();
        for (dir in roots) {
            for (candidate in getModCandidates(normalized)) {
                var checkPath = dir + "/" + candidate;
                if (FileSystem.exists(checkPath)) {
                    return checkPath;
                }
            }
        }
        #end
        return null;
    }

    public static function getPath(assetPath:String):String {
        if (assetPath == null || StringTools.trim(assetPath).length == 0) {
            return "";
        }
        var normalized = normalizeAssetPath(assetPath);
        if (normalized.length == 0) {
            return "";
        }
        #if sys
        for (candidate in getAssetCandidates(normalized)) {
            if (FileSystem.exists(candidate)) {
                return candidate;
            }
        }

        var roots = getActiveModDirectories();
        for (dir in roots) {
            for (candidate in getModCandidates(normalized)) {
                var checkPath = dir + "/" + candidate;
                if (FileSystem.exists(checkPath)) {
                    return checkPath;
                }
            }
        }
        #end
        return normalized;
    }
}