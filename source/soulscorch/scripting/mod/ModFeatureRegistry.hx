package soulscorch.scripting.mod;

import haxe.xml.Access;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;

#if sys
import sys.FileSystem;
#end

using StringTools;

typedef ModSongRulePack = {
    var song:String;
    var ?noteSkin:String;
    var ?defaultCamZoom:Float;
    var ?defaultHUDZoom:Float;
    var ?cameraZoomBeatInterval:Int;
    var ?cameraZoomBeatOffset:Int;
    var ?allowPause:Bool;
    var ?judgeProfile:String;
}

typedef ModEventMacroStep = {
    var delay:Float;
    var name:String;
    var val1:Dynamic;
    var val2:Dynamic;
}

typedef ModCampaignPlaylist = {
    var id:String;
    var title:String;
    var songs:Array<String>;
    var ?difficulties:Array<String>;
}

typedef ModUiSkinPack = {
    var id:String;
    var ?font:String;
    var ?scoreColor:String;
    var ?healthP1Color:String;
    var ?healthP2Color:String;
    var ?isDefault:Bool;
}

typedef ModJudgmentProfile = {
    var id:String;
    var ?marvelous:Float;
    var ?sick:Float;
    var ?good:Float;
    var ?bad:Float;
    var ?shit:Float;
}

class ModFeatureRegistry {
    public static inline var SUPPORTED_API_VERSION:String = "1.0.0";

    public static var stateOverrides:Map<String, String> = new Map<String, String>();
    public static var songRulePacks:Map<String, ModSongRulePack> = new Map<String, ModSongRulePack>();
    public static var eventMacros:Map<String, Array<ModEventMacroStep>> = new Map<String, Array<ModEventMacroStep>>();
    public static var campaigns:Array<ModCampaignPlaylist> = [];
    public static var uiSkinPacks:Map<String, ModUiSkinPack> = new Map<String, ModUiSkinPack>();
    public static var activeUiSkin:Null<ModUiSkinPack> = null;
    public static var judgmentProfiles:Map<String, ModJudgmentProfile> = new Map<String, ModJudgmentProfile>();
    public static var preloadGroups:Map<String, Array<String>> = new Map<String, Array<String>>();

    public static function clear():Void {
        stateOverrides.clear();
        songRulePacks.clear();
        eventMacros.clear();
        campaigns = [];
        uiSkinPacks.clear();
        activeUiSkin = null;
        judgmentProfiles.clear();
        preloadGroups.clear();
    }

    public static function reload():Void {
        clear();

        for (mod in ModManager.activeMods) {
            validateApiVersion(mod);
            loadModFeatures(mod);
        }

        var stateCount = 0;
        for (_ in stateOverrides) stateCount++;
        var ruleCount = 0;
        for (_ in songRulePacks) ruleCount++;
        var macroCount = 0;
        for (_ in eventMacros) macroCount++;

        Logger.info('ModFeatureRegistry loaded (${stateCount} state override(s), ${ruleCount} song rule(s), ${macroCount} event macro(s), ${campaigns.length} campaign(s)).', "mods");
    }

    public static function applyStateRedirects():Void {
        for (fromState => toState in stateOverrides) {
            SoulGlobalScript.redirectState(fromState, toState);
        }
    }

    public static function getSongRule(songId:String):Null<ModSongRulePack> {
        if (songId == null) return null;
        var clean = songId.toLowerCase().trim();
        return songRulePacks.exists(clean) ? songRulePacks.get(clean) : null;
    }

    public static function getEventMacro(name:String):Null<Array<ModEventMacroStep>> {
        if (name == null) return null;
        var clean = name.toLowerCase().trim();
        return eventMacros.exists(clean) ? eventMacros.get(clean) : null;
    }

    public static function getCampaignPlaylists():Array<ModCampaignPlaylist> {
        return campaigns.copy();
    }

    public static function getJudgmentProfile(profileId:String):Null<ModJudgmentProfile> {
        if (profileId == null) return null;
        var clean = profileId.toLowerCase().trim();
        return judgmentProfiles.exists(clean) ? judgmentProfiles.get(clean) : null;
    }

    public static function preloadForSong(songId:String):Void {
        preloadGroup("common");
        if (songId != null && songId.trim().length > 0) {
            preloadGroup('song:' + songId.toLowerCase().trim());
        }
    }

    public static function preloadGroup(groupId:String):Void {
        if (groupId == null) return;
        var clean = groupId.toLowerCase().trim();
        if (!preloadGroups.exists(clean)) return;

        var assets = preloadGroups.get(clean);
        if (assets == null) return;

        for (assetPath in assets) {
            if (assetPath == null || assetPath.trim().length == 0) continue;
            warmAsset(assetPath.trim());
        }
    }

    private static function warmAsset(path:String):Void {
        var lower = path.toLowerCase();

        if (lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
            AssetResolver.getGraphic(path);
            return;
        }

        if (lower.endsWith(".ogg") || lower.endsWith(".mp3") || lower.endsWith(".wav")) {
            AssetResolver.getSound(path);
            return;
        }

        if (lower.endsWith(".xml") || lower.endsWith(".xmsoul") || lower.endsWith(".json") || lower.endsWith(".txt")
            || lower.endsWith(".hx") || lower.endsWith(".hscript") || lower.endsWith(".soul") || lower.endsWith(".lua") || lower.endsWith(".py")) {
            AssetResolver.getText(path);
            return;
        }

        // Unknown extension: probe common asset loaders.
        if (AssetResolver.getGraphic(path) == null && AssetResolver.getSound(path) == null) {
            AssetResolver.getText(path);
        }
    }

    private static function validateApiVersion(mod:String):Void {
        if (mod == null || !ModManager.modConfigs.exists(mod)) return;
        var cfg = ModManager.modConfigs.get(mod);
        if (cfg == null || cfg.api_version == null) return;

        if (!isApiCompatible(cfg.api_version, SUPPORTED_API_VERSION)) {
            Logger.warn('Mod "$mod" targets API ${cfg.api_version}, engine supports $SUPPORTED_API_VERSION. Some features may degrade.', "mods");
        }
    }

    private static function isApiCompatible(modVersion:String, supportedVersion:String):Bool {
        var mod = parseVersion(modVersion);
        var sup = parseVersion(supportedVersion);

        // Same major is compatible. Newer major gets warning.
        return mod.major <= sup.major;
    }

    private static function parseVersion(version:String):{major:Int, minor:Int, patch:Int} {
        if (version == null) return {major: 1, minor: 0, patch: 0};
        var parts = version.trim().split(".");

        var parsePart = function(idx:Int):Int {
            if (idx >= parts.length) return 0;
            var p = Std.parseInt(parts[idx]);
            return p == null ? 0 : p;
        };

        return {
            major: parsePart(0),
            minor: parsePart(1),
            patch: parsePart(2)
        };
    }

    private static function loadModFeatures(mod:String):Void {
        #if sys
        var root = ModManager.getModFolderRootPath(mod);
        var candidates = [
            '$root/$mod/mod_features.xmsoul',
            '$root/$mod/config/mod_features.xmsoul',
            '$root/$mod/data/mod_features.xmsoul',
            '$root/$mod/config/features.xmsoul'
        ];

        for (path in candidates) {
            if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) {
                parseFeatureFile(path);
                return;
            }
        }
        #end
    }

    private static function parseFeatureFile(path:String):Void {
        var xml:Access = XMSoul.parse(path, false, false);
        if (xml == null) return;

        for (node in xml.nodes.resolve("state")) {
            var fromState = XMSoul.getAttr(node, "from", "").trim();
            var toState = XMSoul.getAttr(node, "to", "").trim();
            if (fromState.length > 0 && toState.length > 0) {
                stateOverrides.set(fromState, toState);
            }
        }

        for (node in xml.nodes.resolve("songRule")) {
            var song = XMSoul.getAttr(node, "song", "").toLowerCase().trim();
            if (song.length == 0) continue;

            var rule:ModSongRulePack = {
                song: song,
                noteSkin: nullableText(XMSoul.getAttr(node, "noteSkin", "")),
                defaultCamZoom: nullableFloat(XMSoul.getAttr(node, "defaultCamZoom", "")),
                defaultHUDZoom: nullableFloat(XMSoul.getAttr(node, "defaultHUDZoom", "")),
                cameraZoomBeatInterval: nullableInt(XMSoul.getAttr(node, "cameraZoomBeatInterval", "")),
                cameraZoomBeatOffset: nullableInt(XMSoul.getAttr(node, "cameraZoomBeatOffset", "")),
                allowPause: nullableBool(XMSoul.getAttr(node, "allowPause", "")),
                judgeProfile: nullableText(XMSoul.getAttr(node, "judgeProfile", ""))
            };
            songRulePacks.set(song, rule);
        }

        for (node in xml.nodes.resolve("eventMacro")) {
            var id = XMSoul.getAttr(node, "id", XMSoul.getAttr(node, "name", "")).toLowerCase().trim();
            if (id.length == 0) continue;

            var steps:Array<ModEventMacroStep> = [];
            for (eventNode in node.nodes.resolve("event")) {
                var eventName = XMSoul.getAttr(eventNode, "name", "").trim();
                if (eventName.length == 0) continue;
                steps.push({
                    delay: XMSoul.getFloatAttr(eventNode, "delay", XMSoul.getFloatAttr(eventNode, "time", 0.0)),
                    name: eventName,
                    val1: XMSoul.getAttr(eventNode, "val1", ""),
                    val2: XMSoul.getAttr(eventNode, "val2", "")
                });
            }

            if (steps.length == 0) {
                var inlineName = XMSoul.getAttr(node, "event", "").trim();
                if (inlineName.length > 0) {
                    steps.push({
                        delay: 0.0,
                        name: inlineName,
                        val1: XMSoul.getAttr(node, "val1", ""),
                        val2: XMSoul.getAttr(node, "val2", "")
                    });
                }
            }

            if (steps.length > 0) {
                eventMacros.set(id, steps);
            }
        }

        for (node in xml.nodes.resolve("campaign")) {
            var id = XMSoul.getAttr(node, "id", "").trim();
            if (id.length == 0) continue;

            var title = XMSoul.getAttr(node, "title", id);
            var songs:Array<String> = [];
            for (songNode in node.nodes.resolve("song")) {
                var song = XMSoul.getAttr(songNode, "id", songNode.innerData != null ? songNode.innerData.trim() : "").trim();
                if (song.length > 0) songs.push(song);
            }

            if (songs.length == 0) continue;

            var diffsAttr = XMSoul.getAttr(node, "difficulties", "").trim();
            var diffs = new Array<String>();
            if (diffsAttr.length > 0) {
                for (diff in diffsAttr.split(",")) {
                    var clean = diff.trim();
                    if (clean.length > 0) diffs.push(clean);
                }
            }

            campaigns.push({
                id: id,
                title: title,
                songs: songs,
                difficulties: diffs.length > 0 ? diffs : null
            });
        }

        for (node in xml.nodes.resolve("uiSkin")) {
            var id = XMSoul.getAttr(node, "id", "default").trim();
            if (id.length == 0) id = "default";

            var pack:ModUiSkinPack = {
                id: id,
                font: nullableText(XMSoul.getAttr(node, "font", "")),
                scoreColor: nullableText(XMSoul.getAttr(node, "scoreColor", "")),
                healthP1Color: nullableText(XMSoul.getAttr(node, "healthP1Color", "")),
                healthP2Color: nullableText(XMSoul.getAttr(node, "healthP2Color", "")),
                isDefault: XMSoul.getBoolAttr(node, "default", false)
            };

            uiSkinPacks.set(id.toLowerCase(), pack);
            if (activeUiSkin == null || pack.isDefault == true) {
                activeUiSkin = pack;
            }
        }

        for (node in xml.nodes.resolve("preload")) {
            var group = XMSoul.getAttr(node, "group", "common").toLowerCase().trim();
            if (group.length == 0) group = "common";

            if (!preloadGroups.exists(group)) preloadGroups.set(group, []);
            var target = preloadGroups.get(group);

            for (assetNode in node.nodes.resolve("asset")) {
                var pathAttr = XMSoul.getAttr(assetNode, "path", assetNode.innerData != null ? assetNode.innerData.trim() : "").trim();
                if (pathAttr.length > 0 && !target.contains(pathAttr)) target.push(pathAttr);
            }
        }

        for (node in xml.nodes.resolve("judgmentProfile")) {
            var id = XMSoul.getAttr(node, "id", "").toLowerCase().trim();
            if (id.length == 0) continue;

            var profile:ModJudgmentProfile = {
                id: id,
                marvelous: nullableFloat(XMSoul.getAttr(node, "marvelous", "")),
                sick: nullableFloat(XMSoul.getAttr(node, "sick", "")),
                good: nullableFloat(XMSoul.getAttr(node, "good", "")),
                bad: nullableFloat(XMSoul.getAttr(node, "bad", "")),
                shit: nullableFloat(XMSoul.getAttr(node, "shit", ""))
            };

            judgmentProfiles.set(id, profile);
        }
    }

    private static inline function nullableText(value:String):Null<String> {
        if (value == null) return null;
        var clean = value.trim();
        return clean.length > 0 ? clean : null;
    }

    private static inline function nullableFloat(value:String):Null<Float> {
        if (value == null) return null;
        var clean = value.trim();
        if (clean.length == 0) return null;
        var parsed = Std.parseFloat(clean);
        return Math.isNaN(parsed) ? null : parsed;
    }

    private static inline function nullableInt(value:String):Null<Int> {
        if (value == null) return null;
        var clean = value.trim();
        if (clean.length == 0) return null;
        return Std.parseInt(clean);
    }

    private static inline function nullableBool(value:String):Null<Bool> {
        if (value == null) return null;
        var clean = value.toLowerCase().trim();
        if (clean.length == 0) return null;
        return (clean == "true" || clean == "1" || clean == "yes");
    }
}
