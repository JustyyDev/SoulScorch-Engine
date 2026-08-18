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

    #if (cpp && !neko)
    private static var handlers:DiscordEventHandlers;
    private static var presence:DiscordRichPresence;
    private static var isRunning:Bool = false;
    private static var mutex:Mutex;
    private static var workerThread:Thread;
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
            handlers = DiscordEventHandlers.create();
            handlers.ready = cpp.Function.fromStaticFunction(onReady);
            handlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
            handlers.errored = cpp.Function.fromStaticFunction(onError);

            Discord.Initialize(clientID, cpp.RawPointer.addressOf(handlers), cast 1, null);
            isInitialized = true;
            isRunning = true;

            workerThread = Thread.create(function() {
                while (isRunning) {
                    try {
                        mutex.acquire();
                        Discord.RunCallbacks();
                        mutex.release();
                    } catch (e:Dynamic) {
                        mutex.release();
                    }
                    Sys.sleep(1.0);
                }
            });

            Logger.info('Discord RPC initialized (App ID: $clientID).', "discord");
            changePresence("In the Menus", "Main Menu");
        } catch (e:Dynamic) {
            Logger.error('Failed to initialize Discord RPC: $e', "discord");
            isInitialized = false;
        }
        #end
    }

    /**
     * Allows mods to set their own Discord Application ID at runtime.
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

    /**
     * Resets the client ID back to the engine default.
     */
    public static function resetClientID():Void {
        setClientID(DEFAULT_CLIENT_ID);
    }

    /**
     * Main presence function accessible to engine code and mod scripts.
     */
    public static function changePresence(
        details:String,
        ?state:String,
        ?smallImageKey:String,
        ?hasStartTimestamp:Bool = false,
        ?endTimestamp:Float = 0,
        ?largeImageKey:String = "icon",
        ?largeImageText:String = null
    ):Void {
        #if (cpp && !neko)
        if (!isInitialized) return;

        try {
            mutex.acquire();
            presence = DiscordRichPresence.create();
            presence.details = details;
            presence.state = (state != null) ? state : "";
            presence.largeImageKey = (largeImageKey != null && largeImageKey.length > 0) ? largeImageKey : "icon";
            presence.largeImageText = (largeImageText != null) ? largeImageText : Version.versionString();

            if (smallImageKey != null && smallImageKey.length > 0) {
                presence.smallImageKey = smallImageKey;
                presence.smallImageText = smallImageKey;
            }

            if (hasStartTimestamp) {
                presence.startTimestamp = Std.int(Sys.time());
            }

            if (endTimestamp > 0) {
                presence.endTimestamp = Std.int(endTimestamp);
            }

            Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence));
            mutex.release();
        } catch (e:Dynamic) {
            mutex.release();
            Logger.warn('Failed to update Discord presence: $e', "discord");
        }
        #end
    }

    /**
     * Specialized gameplay presence helper with mod customization.
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

        if (isPaused) {
            stateText = 'Paused (Score: $score | Acc: ${Math.round(accuracy * 100) / 100}%)';
            changePresence(detailsText, stateText, "pause", false, 0, lKey, lText);
        } else {
            stateText = 'Score: $score | Acc: ${Math.round(accuracy * 100) / 100}%';
            var remainingSecs:Float = Math.max(0, (duration - songPosition) / 1000.0);
            var endTime:Float = Sys.time() + remainingSecs;
            changePresence(detailsText, stateText, "playing", false, endTime, lKey, lText);
        }
        #end
    }

    public static function setMenuPresence(menuName:String, ?modIcon:String = "icon"):Void {
        changePresence("In the Menus", menuName, null, true, 0, modIcon);
    }

    public static function setEditorPresence(editorName:String, ?targetName:String):Void {
        var state:String = (targetName != null) ? 'Editing: $targetName' : "Editing";
        changePresence(editorName, state, "editor", true, 0, "icon");
    }

    public static function shutdown():Void {
        #if (cpp && !neko)
        if (!isInitialized) return;
        isRunning = false;
        Discord.Shutdown();
        isInitialized = false;
        Logger.info("Discord RPC shut down.", "discord");
        #end
    }

    override public function destroy():Void {
        shutdown();
        super.destroy();
    }

    #if (cpp && !neko)
    private static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void {
        var user = request[0];
        Logger.info('Discord connected: ' + cast(user.username, String), "discord");
    }

    private static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void {
        Logger.warn('Discord disconnected ($errorCode): ' + cast(message, String), "discord");
    }

    private static function onError(errorCode:Int, message:cpp.ConstCharStar):Void {
        Logger.error('Discord error ($errorCode): ' + cast(message, String), "discord");
    }
    #end
}