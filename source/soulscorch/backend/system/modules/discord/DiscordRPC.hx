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

class DiscordRPC extends ModuleBase {
    public static var instance:DiscordRPC;
    public static inline var DEFAULT_CLIENT_ID:String = "1474847014972952849";

    public static var clientID:String = DEFAULT_CLIENT_ID;
    public static var isInitialized:Bool = false;
    public static var currentDetails:String = "";
    public static var currentState:String = "";
    public static var currentElapsedSeconds:Float = 0.0;

    #if (cpp && !neko)
    private static var handlers:DiscordEventHandlers;
    private static var presence:DiscordRichPresence;
    private static var isRunning:Bool = false;
    private static var mutex:Mutex;
    private static var workerThread:Thread;
    private static var reconnectAttempts:Int = 0;
    private static inline var MAX_RECONNECT_ATTEMPTS:Int = 5;
    #end

    public function new(autoInit:Bool = true) {
        super("discord_rpc");
        instance = this;
        #if (cpp && !neko)
        mutex = new Mutex();
        #end
        if (autoInit) {
            initialize();
        }
    }

    override public function initialize():Void {
        #if (cpp && !neko)
        if (isInitialized) return;

        try {
            mutex.acquire();
            handlers = DiscordEventHandlers.create();
            handlers.ready = cpp.Function.fromStaticFunction(onReady);
            handlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
            handlers.errored = cpp.Function.fromStaticFunction(onError);

            Discord.Initialize(clientID, cpp.RawPointer.addressOf(handlers), cast 1, null);
            isInitialized = true;
            isRunning = true;
            reconnectAttempts = 0;
            mutex.release();

            startWorkerThread();

            Logger.info('Discord RPC initialized successfully (App ID: $clientID).', "discord");
            setMenuPresence("Main Menu");
        } catch (e:Dynamic) {
            if (mutex != null) mutex.release();
            Logger.error('Failed to initialize Discord RPC: $e', "discord");
            isInitialized = false;
        }
        #end
    }

    #if (cpp && !neko)
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
                    Logger.warn('Error in Discord callback loop: $e', "discord");
                }
                Sys.sleep(1.0);
            }
        });
    }
    #end

    /**
     * Allows mods or engine states to set their own Discord Application ID at runtime.
     */
    public static function setClientID(newID:String):Void {
        #if (cpp && !neko)
        if (newID == null || newID.length == 0 || newID == clientID) return;

        var wasRunning:Bool = isInitialized;
        if (wasRunning) {
            shutdown();
        }

        clientID = newID;

        if (wasRunning) {
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

    /**
     * Core presence update function with comprehensive parameter support.
     */
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
        ?partyId:String = null
    ):Void {
        #if (cpp && !neko)
        if (!isInitialized) return;

        try {
            mutex.acquire();
            currentDetails = details;
            currentState = (state != null) ? state : "";

            presence = DiscordRichPresence.create();
            presence.details = details;
            presence.state = currentState;
            presence.largeImageKey = (largeImageKey != null && largeImageKey.length > 0) ? largeImageKey : "icon";
            presence.largeImageText = (largeImageText != null) ? largeImageText : Version.versionString();

            if (smallImageKey != null && smallImageKey.length > 0) {
                presence.smallImageKey = smallImageKey;
                presence.smallImageText = smallImageKey;
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
            }

            if (partyId != null && partyId.length > 0) {
                presence.partyId = partyId;
                presence.partySize = partySize;
                presence.partyMax = partyMax;
            }

            Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence));
            mutex.release();
        } catch (e:Dynamic) {
            try { mutex.release(); } catch (err:Dynamic) {}
            Logger.warn('Failed to update Discord presence: $e', "discord");
        }
        #end
    }

    /**
     * Specialized gameplay presence helper for rhythm game levels.
     */
    public static function updateSongPresence(
        songName:String,
        difficulty:String,
        duration:Float,
        songPosition:Float = 0.0,
        accuracy:Float = 0.0,
        score:Int = 0,
        isPaused:Bool = false,
        ?iconKey:String = "icon",
        ?iconText:String = null
    ):Void {
        #if (cpp && !neko)
        if (!isInitialized) return;

        var detailsText:String = '$songName [${difficulty.toUpperCase()}]';
        var stateText:String = "";
        var lKey:String = (iconKey != null && iconKey.length > 0) ? iconKey : "icon";
        var lText:String = (iconText != null) ? iconText : Version.versionString();
        var roundedAcc:Float = Math.round(accuracy * 100) / 100;

        if (isPaused) {
            stateText = 'Paused | Score: $score | Acc: $roundedAcc%';
            changePresence(detailsText, stateText, "pause", false, 0, lKey, lText);
        } else {
            stateText = 'Score: $score | Acc: $roundedAcc%';
            var remainingSecs:Float = Math.max(0, (duration - songPosition) / 1000.0);
            var endTime:Float = Sys.time() + remainingSecs;
            changePresence(detailsText, stateText, "playing", false, endTime, lKey, lText);
        }
        #end
    }

    public static function setMenuPresence(menuName:String, ?modIcon:String = "icon"):Void {
        currentElapsedSeconds = 0; // Reset session timer on menu switch
        changePresence("In the Menus", menuName, null, true, 0, modIcon);
    }

    public static function setEditorPresence(editorName:String, ?targetName:String):Void {
        var state:String = (targetName != null) ? 'Editing: $targetName' : "In Development";
        changePresence(editorName, state, "editor", true, 0, "icon");
    }

    public static function setStoryModePresence(weekName:String, difficulty:String):Void {
        changePresence('Story Mode: $weekName', 'Difficulty: ${difficulty.toUpperCase()}', "storymode", true, 0, "icon");
    }

    public static function setFreeplayPresence(songCount:Int):Void {
        changePresence("Freeplay Selection", 'Browsing $songCount tracks', "freeplay", true, 0, "icon");
    }

    public static function setResultsPresence(songName:String, score:Int, accuracy:Float, rank:String):Void {
        var roundedAcc:Float = Math.round(accuracy * 100) / 100;
        changePresence('Results: $songName', 'Rank: $rank | Score: $score | Acc: $roundedAcc%', "results", false, 0, "icon");
    }

    public static function shutdown():Void {
        #if (cpp && !neko)
        if (!isInitialized) return;
        isRunning = false;
        try {
            Discord.Shutdown();
        } catch (e:Dynamic) {}
        isInitialized = false;
        Logger.info("Discord RPC shut down cleanly.", "discord");
        #end
    }

    override public function destroy():Void {
        shutdown();
        super.destroy();
    }

    #if (cpp && !neko)
    private static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void {
        var user = request[0];
        var username = cast(user.username, String);
        var discrim = cast(user.discriminator, String);
        Logger.info('Discord Rich Presence connected as $username#$discrim', "discord");
    }

    private static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void {
        var msg = cast(message, String);
        Logger.warn('Discord RPC disconnected ($errorCode): $msg', "discord");
        
        if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS && isInitialized) {
            reconnectAttempts++;
            Logger.info('Attempting Discord RPC reconnection (${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})...', "discord");
        }
    }

    private static function onError(errorCode:Int, message:cpp.ConstCharStar):Void {
        var msg = cast(message, String);
        Logger.error('Discord RPC runtime error ($errorCode): $msg', "discord");
    }
    #end
}