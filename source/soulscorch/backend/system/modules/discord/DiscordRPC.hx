package soulscorch.backend.system.modules.discord;

import haxe.xml.Access;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.system.modules.Module.ModuleBase;
import soulscorch.backend.utils.Logger;

#if (cpp && !mobile && !neko)
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;
import sys.thread.Mutex;
import sys.thread.Thread;
#end

using StringTools;

class DiscordRPC extends ModuleBase {
    public static var instance:DiscordRPC;
    public static inline var DEFAULT_CLIENT_ID:String = "1474847014972952849";

    public static var clientID:String = DEFAULT_CLIENT_ID;
    public static var isInitialized:Bool = false;
    public static var isEnabled:Bool = true;
    public static var currentDetails:String = "";
    public static var currentState:String = "";
    public static var currentElapsedSeconds:Float = 0.0;
    public static var currentEndTime:Float = 0.0;
    public static var currentLargeKey:String = "icon";
    public static var currentLargeText:String = "";
    public static var currentSmallKey:String = "";
    public static var currentSmallText:String = "";

    private static var lastUpdateTime:Float = 0.0;
    private static inline var MIN_UPDATE_INTERVAL:Float = 1.5;
    private static var isDirty:Bool = false;

    #if (cpp && !mobile && !neko)
    private static var handlers:DiscordEventHandlers;
    private static var isRunning:Bool = false;
    private static var mutex:Mutex;
    private static var workerThread:Thread;
    #end

    public function new(autoInit:Bool = true) {
        super("discord_rpc");
        instance = this;
        #if (cpp && !mobile && !neko)
        if (mutex == null) mutex = new Mutex();
        #end
        loadConfigFromXMSoul();
        if (autoInit && isEnabled) {
            initialize();
        }
    }

    public static function loadConfigFromXMSoul():Void {
        var access:Access = XMSoul.parse("config/discord");
        if (access == null) access = XMSoul.parse("data/config/discord");

        if (access != null) {
            isEnabled = XMSoul.getBoolAttr(access, "enabled", true);
            var customID = XMSoul.getAttr(access, "clientID", DEFAULT_CLIENT_ID);
            if (customID.length > 0) clientID = customID;

            currentLargeKey = XMSoul.getAttr(access, "defaultLargeKey", "icon");
            currentLargeText = XMSoul.getAttr(access, "defaultLargeText", 'SoulScorch ${Version.versionString()}');
            Logger.info('Discord RPC manifest loaded from .xmsoul (App ID: $clientID)', "discord");
        }
    }

    override public function initialize():Void {
        #if (cpp && !mobile && !neko)
        if (isInitialized || !isEnabled) return;

        try {
            mutex.acquire();

            handlers = untyped __cpp__("DiscordEventHandlers()");
            handlers.ready = cpp.Function.fromStaticFunction(onReady);
            handlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
            handlers.errored = cpp.Function.fromStaticFunction(onError);

            Discord.Initialize(clientID, cpp.RawPointer.addressOf(handlers), true, null);
            isInitialized = true;
            isRunning = true;
            mutex.release();

            startWorkerThread();

            Logger.info('Discord RPC initialized (App ID: $clientID).', "discord");
            setMenuPresence("Main Menu");
        } catch (e:Dynamic) {
            if (mutex != null) {
                try { mutex.release(); } catch (err:Dynamic) {}
            }
            Logger.error('Failed to initialize Discord RPC: $e', "discord");
            isInitialized = false;
        }
        #end
    }

    #if (cpp && !mobile && !neko)
    private static function startWorkerThread():Void {
        if (workerThread != null) return;

        workerThread = Thread.create(function() {
            while (isRunning) {
                try {
                    mutex.acquire();
                    Discord.RunCallbacks();
                    mutex.release();
                } catch (e:Dynamic) {
                    try { mutex.release(); } catch (err:Dynamic) {}
                }
                Sys.sleep(1.0);
            }
            workerThread = null;
        });
    }
    #end

    public static function poll():Void {
        #if (cpp && !mobile && !neko)
        if (!isInitialized || !isRunning || !isEnabled) return;
        try {
            if (mutex.tryAcquire()) {
                Discord.RunCallbacks();
                mutex.release();
            }
        } catch (e:Dynamic) {}
        #end
    }

    public static function setClientID(newID:String):Void {
        #if (cpp && !mobile && !neko)
        if (newID == null || newID.trim().length == 0 || newID == clientID) return;

        var wasRunning:Bool = isInitialized;
        if (wasRunning) {
            shutdown();
        }

        clientID = newID.trim();

        if (wasRunning && isEnabled) {
            if (instance != null) {
                instance.initialize();
            } else {
                new DiscordRPC(true);
            }
        }
        #end
    }

    public static function resetClientID():Void {
        setClientID(DEFAULT_CLIENT_ID);
    }

    public static function changePresence(
        details:String,
        ?state:String,
        ?smallImageKey:String,
        ?hasStartTimestamp:Bool = false,
        ?endTimestamp:Float = 0,
        ?largeImageKey:String = "icon",
        ?largeImageText:String = null,
        ?partySize:Int = 0,
        ?partyMax:Int = 0,
        ?partyId:String = null,
        forced:Bool = false
    ):Void {
        #if (cpp && !mobile && !neko)
        if (!isEnabled) return;

        if (!isInitialized) {
            if (instance != null) instance.initialize();
            else new DiscordRPC(true);
        }

        var currentTime = Sys.time();
        if (!forced && (currentTime - lastUpdateTime < MIN_UPDATE_INTERVAL)) {
            isDirty = true;
        }

        try {
            mutex.acquire();

            currentDetails = (details != null && details.length > 0) ? details : "SoulScorch Engine";
            currentState = (state != null) ? state : "";
            currentLargeKey = (largeImageKey != null && largeImageKey.length > 0) ? largeImageKey : "icon";
            currentLargeText = (largeImageText != null && largeImageText.length > 0) ? largeImageText : Version.fullVersion();
            currentSmallKey = (smallImageKey != null) ? smallImageKey : "";
            currentSmallText = (smallImageKey != null) ? smallImageKey : "";

            var presence:DiscordRichPresence = untyped __cpp__("DiscordRichPresence()");
            presence.details = currentDetails;
            presence.state = currentState;
            presence.largeImageKey = currentLargeKey;
            presence.largeImageText = currentLargeText;

            if (currentSmallKey.length > 0) {
                presence.smallImageKey = currentSmallKey;
                presence.smallImageText = currentSmallText;
            }

            if (hasStartTimestamp) {
                if (currentElapsedSeconds <= 0) {
                    currentElapsedSeconds = Std.int(Sys.time());
                }
                presence.startTimestamp = Std.int(currentElapsedSeconds);
            } else {
                currentElapsedSeconds = 0;
                presence.startTimestamp = 0;
            }

            if (endTimestamp > 0) {
                presence.endTimestamp = Std.int(endTimestamp);
            } else {
                presence.endTimestamp = 0;
            }

            if (partyId != null && partyId.length > 0 && partyMax > 0) {
                presence.partyId = partyId;
                presence.partySize = partySize;
                presence.partyMax = partyMax;
            }

            Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence));
            Discord.RunCallbacks();
            lastUpdateTime = currentTime;
            isDirty = false;
            mutex.release();
        } catch (e:Dynamic) {
            if (mutex != null) {
                try { mutex.release(); } catch (err:Dynamic) {}
            }
            Logger.warn('Failed to update Discord presence: $e', "discord");
        }
        #end
    }

    public static function updateSongPresence(
        songName:String,
        difficulty:String,
        duration:Float,
        songPosition:Float = 0.0,
        accuracy:Float = 0.0,
        score:Int = 0,
        misses:Int = 0,
        isPaused:Bool = false,
        ?iconKey:String = "icon",
        ?iconText:String = null
    ):Void {
        #if (cpp && !mobile && !neko)
        if (!isEnabled) return;
        var detailsText:String = '$songName [${difficulty.toUpperCase()}]';
        var roundedAcc:Float = Math.round(accuracy * 100) / 100;
        var lKey:String = (iconKey != null && iconKey.length > 0) ? iconKey : "icon";
        var lText:String = (iconText != null) ? iconText : Version.versionString();

        if (isPaused) {
            var stateText = 'Paused | Score: $score | Misses: $misses | Acc: $roundedAcc%';
            changePresence(detailsText, stateText, "pause", false, 0, lKey, lText, false);
        } else {
            var stateText = 'Score: $score | Misses: $misses | Acc: $roundedAcc%';
            var remainingSecs:Float = Math.max(0, (duration - songPosition) / 1000.0);
            var endTime:Float = Sys.time() + remainingSecs;
            changePresence(detailsText, stateText, "playing", false, endTime, lKey, lText, false);
        }
        #end
    }

    public static function setMenuPresence(menuName:String, ?modIcon:String = "icon"):Void {
        currentElapsedSeconds = 0;
        changePresence("Main Menus", menuName, null, true, 0, modIcon);
    }

    public static function setEditorPresence(editorName:String, ?targetName:String):Void {
        var state:String = (targetName != null && targetName.length > 0) ? 'Editing: $targetName' : "In Editor";
        changePresence('Editor: $editorName', state, "editor", true, 0, "icon");
    }

    public static function setStoryModePresence(weekName:String, difficulty:String, currentTrack:Int = 1, totalTracks:Int = 3):Void {
        var state = 'Track $currentTrack of $totalTracks (${difficulty.toUpperCase()})';
        changePresence('Story Mode: $weekName', state, "storymode", true, 0, "icon");
    }

    public static function setFreeplayPresence(category:String = "Original", songCount:Int = 0):Void {
        var state = (songCount > 0) ? 'Browsing $songCount tracks ($category)' : 'Browsing tracks ($category)';
        changePresence("Freeplay Menu", state, "freeplay", true, 0, "icon");
    }

    public static function setResultsPresence(songName:String, difficulty:String, score:Int, misses:Int, accuracy:Float, rank:String):Void {
        var roundedAcc:Float = Math.round(accuracy * 100) / 100;
        var detailsText = '$songName [${difficulty.toUpperCase()}]';
        var stateText = 'Rank: $rank | Score: $score | Misses: $misses | Acc: $roundedAcc%';
        changePresence(detailsText, stateText, "results", false, 0, "icon", 'SoulScorch ${Version.versionString()}');
    }

    public static function setModPresence(modName:String, modVersion:String = "1.0", ?subStateName:String):Void {
        var stateText = (subStateName != null) ? '$modName ($modVersion) - $subStateName' : '$modName ($modVersion)';
        changePresence("Playing Custom Mod", stateText, "mod", true, 0, "icon");
    }

    public static function shutdown():Void {
        #if (cpp && !mobile && !neko)
        if (!isInitialized) return;
        isRunning = false;
        try {
            if (mutex != null) mutex.acquire();
            Discord.ClearPresence();
            Discord.Shutdown();
            if (mutex != null) mutex.release();
        } catch (e:Dynamic) {
            if (mutex != null) {
                try { mutex.release(); } catch (err:Dynamic) {}
            }
        }
        isInitialized = false;
        Logger.info("Discord RPC shut down cleanly.", "discord");
        #end
    }

    override public function destroy():Void {
        shutdown();
        super.destroy();
    }

    #if (cpp && !mobile && !neko)
    private static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void {
        var user = request[0];
        var username = cast(user.username, String);
        var discriminator = cast(user.discriminator, String);
        var userTag = (discriminator != "0" && discriminator != null) ? '$username#$discriminator' : username;
        Logger.info('Discord Rich Presence connected as $userTag', "discord");
    }

    private static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void {
        var msg = cast(message, String);
        Logger.warn('Discord RPC disconnected ($errorCode): $msg', "discord");
    }

    private static function onError(errorCode:Int, message:cpp.ConstCharStar):Void {
        var msg = cast(message, String);
        Logger.error('Discord RPC runtime error ($errorCode): $msg', "discord");
    }
    #end
}