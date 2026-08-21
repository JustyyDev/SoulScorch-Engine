package soulscorch.backend;

import haxe.xml.Access;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.utils.Logger;
import soulscorch.gameplay.song.SongMetadata;
import soulscorch.scripting.mod.ModManager;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class FreeplayListManager {
    public static function loadSongs():Array<SongMetadata> {
        var songList:Array<SongMetadata> = [];
        var freeplayPath:String = null;

        // 1. Strict Active Mod Override (First Mod with a Freeplay List Claims the Slot)
        #if sys
        for (mod in ModManager.activeMods) {
            var candidatePaths = [
                'mods/$mod/data/config/freeplay.xmsoul',
                'mods/$mod/data/config/freeplay.xml',
                'mods/$mod/data/freeplay.xmsoul',
                'mods/$mod/data/freeplay.xml',
                'mods/$mod/freeplay.xmsoul'
            ];
            for (p in candidatePaths) {
                if (FileSystem.exists(p)) {
                    freeplayPath = p;
                    Logger.info('Freeplay replaced by active mod tracklist: $freeplayPath', "freeplay");
                    break;
                }
            }
            if (freeplayPath != null) break;
        }
        #end

        // 2. Base Fallback only if no active mod declared a list
        if (freeplayPath == null) {
            var defaultProbes = [
                "data/config/freeplay.xmsoul",
                "data/config/freeplay.xml",
                "assets/preload/data/config/freeplay.xmsoul",
                "assets/data/config/freeplay.xmsoul"
            ];
            for (dp in defaultProbes) {
                var res = Paths.getPath(dp);
                #if sys
                if (res != null && FileSystem.exists(res)) {
                    freeplayPath = res;
                    break;
                }
                #else
                if (Paths.exists(dp)) {
                    freeplayPath = dp;
                    break;
                }
                #end
            }
        }

        if (freeplayPath == null) {
            Logger.warn("No freeplay.xmsoul found; generating fallback track list.", "freeplay");
            songList.push(SongMetadataHelper.createDefault("Tutorial"));
            return songList;
        }

        // 3. Absolute Single-Source Parsing
        var xml = XMSoul.parse(freeplayPath, false);
        if (xml != null) {
            for (node in xml.elements) {
                if (node.name.toLowerCase() == "song") {
                    var title = XMSoul.getAttr(node, "name", XMSoul.getAttr(node, "title", "Tutorial"));
                    var iconName = XMSoul.getAttr(node, "icon", XMSoul.getAttr(node, "freeplayIcon", title.toLowerCase()));
                    var diffs = XMSoul.getArrayAttr(node, "difficulties", ",");
                    if (diffs.length == 0) diffs = ["Easy", "Normal", "Hard"];

                    var meta:SongMetadata = {
                        title: title,
                        artist: XMSoul.getAttr(node, "artist", "Unknown"),
                        charter: XMSoul.getAttr(node, "charter", "Unknown"),
                        bpm: XMSoul.getFloatAttr(node, "bpm", 100.0),
                        speed: XMSoul.getFloatAttr(node, "speed", 1.0),
                        stage: XMSoul.getAttr(node, "stage", "stage"),
                        player1: XMSoul.getAttr(node, "player1", "bf"),
                        player2: XMSoul.getAttr(node, "player2", "dad"),
                        gfVersion: XMSoul.getAttr(node, "gfVersion", "gf"),
                        difficulties: diffs,
                        color: XMSoul.getAttr(node, "color", "#AF66CE"),
                        freeplayIcon: iconName,
                        icon: iconName,
                        cutscene: XMSoul.getAttr(node, "cutscene", ""),
                        endCutscene: XMSoul.getAttr(node, "endCutscene", ""),
                        needsVoices: XMSoul.getBoolAttr(node, "needsVoices", true),
                        coopAllowed: XMSoul.getBoolAttr(node, "coopAllowed", false),
                        opponentModeAllowed: XMSoul.getBoolAttr(node, "opponentModeAllowed", false),
                        previewStart: XMSoul.getFloatAttr(node, "previewStart", 0.0),
                        previewEnd: XMSoul.getFloatAttr(node, "previewEnd", 0.0),
                        week: XMSoul.getIntAttr(node, "week", 1),
                        locked: XMSoul.getBoolAttr(node, "locked", false),
                        folder: XMSoul.getAttr(node, "folder", "")
                    };

                    songList.push(meta);
                }
            }
            Logger.info('Successfully parsed ${songList.length} track(s) from $freeplayPath', "freeplay");
        }

        return songList;
    }
}