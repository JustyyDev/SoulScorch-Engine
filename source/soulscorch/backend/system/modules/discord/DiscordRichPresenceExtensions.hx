package soulscorch.backend.system.modules.discord;

import soulscorch.backend.system.modules.Module.ModuleBase;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.utils.Logger;

#if (cpp && !neko)
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;
import sys.thread.Mutex;
import sys.thread.Thread;
#end

class DiscordRichPresenceExtensions extends ModuleBase {
    public static var instance:DiscordRichPresenceExtensions;

    public function new() {
        super("discord_rpc_extensions");
        instance = this;
    }

    /**
     * Sets presence for chart editing, mapping, or audio sync tweaking.
     */
    public static function setChartEditorPresence(songName:String, currentStep:Int, bpm:Float):Void {
        #if (cpp && !neko)
        DiscordRPC.changePresence(
            'Charting: $songName',
            'Step: $currentStep | BPM: ${Math.round(bpm * 100) / 100}',
            "editor",
            true,
            0,
            "icon",
            'SoulScorch v' + Version.fullVersion()
        );
        #end
    }

    /**
     * Sets presence for custom mod script debugging or console work.
     */
    public static function setScriptDebuggingPresence(scriptName:String):Void {
        #if (cpp && !neko)
        DiscordRPC.changePresence(
            'Debugging Mod',
            'Script: $scriptName',
            "terminal",
            true,
            0,
            "icon",
            'SoulScorch v' + Version.fullVersion()
        );
        #end
    }

    /**
     * Sets presence for multiplayer lobbies or co-op gameplay matching.
     */
    public static function setLobbyPresence(lobbyName:String, currentPlayers:Int, maxPlayers:Int, partyId:String):Void {
        #if (cpp && !neko)
        DiscordRPC.changePresence(
            'Multiplayer Lobby',
            'Room: $lobbyName',
            "multiplayer",
            true,
            0,
            "icon",
            'SoulScorch v' + Version.fullVersion(),
            currentPlayers,
            maxPlayers,
            partyId
        );
        #end
    }

    /**
     * Sets presence when viewing achievements, unlocks, or completion stats.
     */
    public static function setAchievementsPresence(unlockedCount:Int, totalCount:Int):Void {
        #if (cpp && !neko)
        var percentage:Int = Std.int((unlockedCount / totalCount) * 100);
        DiscordRPC.changePresence(
            'Viewing Achievements',
            'Completed: $unlockedCount/$totalCount ($percentage%)',
            "trophy",
            true,
            0,
            "icon",
            'SoulScorch v' + Version.fullVersion()
        );
        #end
    }

    /**
     * Sets presence when listening to custom music tracks in an audio or jukebox player menu.
     */
    public static function setMusicPlayerPresence(trackTitle:String, artistName:String):Void {
        #if (cpp && !neko)
        DiscordRPC.changePresence(
            'Listening to OST',
            '$trackTitle - $artistName',
            "music",
            true,
            0,
            "icon",
            'SoulScorch v' + Version.fullVersion()
        );
        #end
    }
}