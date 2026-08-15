package soulscorch.backend;

#if desktop
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;
import sys.thread.Thread;
#end

class DiscordRPC {
    public static inline var CLIENT_ID:String = "1474847014972952849";
    public static var isInitialized:Bool = false;

    #if desktop
    private static var handlers:DiscordEventHandlers;
    private static var presence:DiscordRichPresence;
    private static var isRunning:Bool = false;
    #end

    public static function initialize():Void {
        #if desktop
        if (isInitialized) return;

        handlers = cast {};
        handlers.ready = cpp.Function.fromStaticFunction(onReady);
        handlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
        handlers.errored = cpp.Function.fromStaticFunction(onError);

        // Client ID, Handlers Pointer, autoRegister (Bool), optional steamId (String)
        Discord.Initialize(CLIENT_ID, cpp.RawPointer.addressOf(handlers), true, null);
        isInitialized = true;
        isRunning = true;

        // Background worker thread for non-blocking RPC callbacks
        Thread.create(function() {
            while (isRunning) {
                #if cpp
                Discord.RunCallbacks();
                #end
                Sys.sleep(1.0);
            }
        });

        Sys.println('[DISCORD] RPC initialized with Client ID: ' + CLIENT_ID);
        changePresence("In the Menus", "Main Menu");
        #end
    }

    public static function changePresence(details:String, ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool = false, ?endTimestamp:Float = 0, ?largeImageKey:String = "icon"):Void {
        #if desktop
        if (!isInitialized) return;

        presence = cast {};
        presence.details = details;
        presence.state = state != null ? state : "";
        presence.largeImageKey = largeImageKey != null ? largeImageKey : "icon";
        presence.largeImageText = "SoulScorch Engine";

        if (smallImageKey != null && smallImageKey != "") {
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
        #end
    }

    public static function updateSongPresence(songName:String, difficulty:String, remainingSeconds:Float, ?accuracy:Float = 0.0, ?score:Int = 0):Void {
        #if desktop
        if (!isInitialized) return;

        var detailsText = '$songName [${difficulty.toUpperCase()}]';
        var stateText = score > 0 ? 'Score: $score | Acc: ${Math.round(accuracy * 100) / 100}%' : "Playing";
        var endTime = Sys.time() + remainingSeconds;

        changePresence(detailsText, stateText, "playing", false, endTime, "icon");
        #end
    }

    public static function shutdown():Void {
        #if desktop
        if (!isInitialized) return;
        isRunning = false;
        Discord.Shutdown();
        isInitialized = false;
        Sys.println('[DISCORD] RPC shut down successfully.');
        #end
    }

    #if desktop
    private static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void {
        var user = request[0];
        Sys.println('[DISCORD] Connected to user: ' + cast(user.username, String));
    }

    private static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void {
        Sys.println('[DISCORD] Disconnected ($errorCode): ' + cast(message, String));
    }

    private static function onError(errorCode:Int, message:cpp.ConstCharStar):Void {
        Sys.println('[DISCORD] Error ($errorCode): ' + cast(message, String));
    }
    #end
}