package soulscorch.backend.system.modules.discord;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
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
#elseif (hl && sys)
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.net.Socket;
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
    private static var lastPresenceSignature:String = "";
    private static inline var MIN_UPDATE_INTERVAL:Float = 1.0;

    #if (cpp && !mobile && !neko)
    private static var handlers:DiscordEventHandlers;
    private static var isRunning:Bool = false;
    private static var mutex:Mutex;
    private static var workerThread:Thread;
    #elseif (hl && sys)
    private static var isRunning:Bool = false;
    private static var mutex:Mutex;
    private static var pipeHandle:Dynamic = null;
    private static var pipeInput:FileInput = null;
    private static var pipeOutput:FileOutput = null;
    private static var socket:Socket = null;
    private static var workerThread:Thread;
    private static var pendingPresence:Dynamic = null;
    #end

    public function new(autoInit:Bool = true) {
        super("discord_rpc");
        instance = this;
        
        #if ((cpp && !mobile && !neko) || (hl && sys))
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
        if (access == null) access = XMSoul.parse("data/discord.xmsoul");

        if (access != null) {
            isEnabled = XMSoul.getBoolAttr(access, "enabled", true);
            var customID = XMSoul.getAttr(access, "clientID", DEFAULT_CLIENT_ID);
            if (customID.length > 0) clientID = customID;

            currentLargeKey = XMSoul.getAttr(access, "defaultLargeKey", "icon");
            currentLargeText = XMSoul.getAttr(access, "defaultLargeText", 'SoulScorch ${Version.versionString()}');
            Logger.info('Discord RPC manifest loaded (App ID: $clientID)', "discord");
        }
    }

    override public function initialize():Void {
        if (isInitialized || !isEnabled) return;

        #if (cpp && !mobile && !neko)
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
            Logger.info('Discord RPC initialized via native hxdiscord_rpc (App ID: $clientID).', "discord");
            setMenuPresence("Main Menu");
        } catch (e:Dynamic) {
            if (mutex != null) try { mutex.release(); } catch (err:Dynamic) {}
            Logger.error('Failed to initialize Discord RPC on C++: $e', "discord");
            isInitialized = false;
        }
        #elseif (hl && sys)
        try {
            mutex.acquire();
            var connected = connectIPC();
            if (connected) {
                isInitialized = true;
                isRunning = true;
                sendHandshake();
                startHLWorkerThread();
                Logger.info('Discord RPC initialized via HashLink IPC Pipe (App ID: $clientID).', "discord");
                setMenuPresence("Main Menu");
            } else {
                Logger.warn("Discord RPC: Discord client is not running locally.", "discord");
            }
            mutex.release();
        } catch (e:Dynamic) {
            if (mutex != null) try { mutex.release(); } catch (err:Dynamic) {}
            Logger.warn('Discord RPC failed on HashLink: $e', "discord");
            isInitialized = false;
        }
        #end
    }

    #if (hl && sys)
    private static function connectIPC():Bool {
        #if windows
        for (i in 0...10) {
            var pipePath = '\\\\.\\pipe\\discord-ipc-$i';
            try {
                pipeInput = File.read(pipePath, true);
                pipeOutput = File.write(pipePath, true);
                return true;
            } catch (e:Dynamic) {}
        }
        #else
        var tempDirs = [
            Sys.getEnv("XDG_RUNTIME_DIR"),
            Sys.getEnv("TMPDIR"),
            Sys.getEnv("TMP"),
            Sys.getEnv("TEMP"),
            "/tmp"
        ];

        for (dir in tempDirs) {
            if (dir == null || !sys.FileSystem.exists(dir)) continue;
            for (i in 0...10) {
                var sockPath = '$dir/discord-ipc-$i';
                if (sys.FileSystem.exists(sockPath)) {
                    try {
                        socket = new Socket();
                        socket.connect(new sys.net.Host(sockPath), 0);
                        return true;
                    } catch (e:Dynamic) {}
                }
            }
        }
        #end
        return false;
    }

    private static function sendHandshake():Void {
        var payload = Json.stringify({
            "v": 1,
            "client_id": clientID
        });
        sendFrame(0, payload);
    }

    private static function sendFrame(opCode:Int, jsonPayload:String):Void {
        try {
            var dataBytes = Bytes.ofString(jsonPayload);
            var out = new BytesOutput();
            out.writeInt32(opCode);
            out.writeInt32(dataBytes.length);
            out.writeBytes(dataBytes, 0, dataBytes.length);
            var buffer = out.getBytes();

            #if windows
            if (pipeOutput != null) {
                pipeOutput.writeBytes(buffer, 0, buffer.length);
                pipeOutput.flush();
            }
            #else
            if (socket != null) {
                socket.output.writeBytes(buffer, 0, buffer.length);
                socket.output.flush();
            }
            #end
        } catch (e:Dynamic) {
            Logger.warn('Discord IPC send failure: $e', "discord");
        }
    }

    private static function startHLWorkerThread():Void {
        if (workerThread != null) return;

        workerThread = Thread.create(function() {
            while (isRunning) {
                try {
                    mutex.acquire();
                    if (pendingPresence != null) {
                        var packet = Json.stringify({
                            "cmd": "SET_ACTIVITY",
                            "args": {
                                "pid": #if sys Sys.getEnv("PID") != null ? Std.parseInt(Sys.getEnv("PID")) : 1000 #else 1000 #end,
                                "activity": pendingPresence
                            },
                            "nonce": Std.string(Sys.time())
                        });
                        sendFrame(1, packet);
                        pendingPresence = null;
                    }
                    mutex.release();
                } catch (e:Dynamic) {
                    try { mutex.release(); } catch (err:Dynamic) {}
                }
                Sys.sleep(0.5);
            }
            workerThread = null;
        });
    }
    #end

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
        if (!isEnabled) return;

        if (!isInitialized) {
            if (instance != null) instance.initialize();
            else new DiscordRPC(true);
        }

        var currentTime = Sys.time();
        if (!forced && (currentTime - lastUpdateTime < MIN_UPDATE_INTERVAL)) return;

        currentDetails = (details != null && details.length > 0) ? details : "SoulScorch Engine";
        currentState = (state != null) ? state : "";
        currentLargeKey = (largeImageKey != null && largeImageKey.length > 0) ? largeImageKey : "icon";
        currentLargeText = (largeImageText != null && largeImageText.length > 0) ? largeImageText : Version.fullVersion();
        currentSmallKey = (smallImageKey != null) ? smallImageKey : "";
        currentSmallText = (smallImageKey != null) ? smallImageKey : "";

        // No-op guard: if nothing actually changed, skip building/sending the presence entirely.
        var signature:String = '$currentDetails|$currentState|$currentLargeKey|$currentLargeText|$currentSmallKey|$hasStartTimestamp|$endTimestamp|$partyId';
        if (!forced && signature == lastPresenceSignature) return;
        lastPresenceSignature = signature;

        #if (cpp && !mobile && !neko)
        try {
            mutex.acquire();
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
                if (currentElapsedSeconds <= 0) currentElapsedSeconds = Std.int(Sys.time());
                presence.startTimestamp = Std.int(currentElapsedSeconds);
            } else {
                currentElapsedSeconds = 0;
                presence.startTimestamp = 0;
            }

            if (endTimestamp > 0) presence.endTimestamp = Std.int(endTimestamp);
            else presence.endTimestamp = 0;

            if (partyId != null && partyId.length > 0 && partyMax > 0) {
                presence.partyId = partyId;
                presence.partySize = partySize;
                presence.partyMax = partyMax;
            }

            // NOTE: Do NOT call Discord.RunCallbacks() here. poll() already runs
            // callbacks every frame from Main.onEnterFrame, so calling it again
            // on every presence change is redundant cross-thread work.
            Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence));
            lastUpdateTime = currentTime;
            mutex.release();
        } catch (e:Dynamic) {
            if (mutex != null) try { mutex.release(); } catch (err:Dynamic) {}
            Logger.warn('Failed to update Discord presence: $e', "discord");
        }
        #elseif (hl && sys)
        try {
            mutex.acquire();
            var timestamps:Dynamic = {};
            if (hasStartTimestamp) {
                if (currentElapsedSeconds <= 0) currentElapsedSeconds = Std.int(Sys.time());
                timestamps.start = Std.int(currentElapsedSeconds);
            }
            if (endTimestamp > 0) timestamps.end = Std.int(endTimestamp);

            var assets:Dynamic = {
                large_image: currentLargeKey,
                large_text: currentLargeText
            };
            if (currentSmallKey.length > 0) {
                assets.small_image = currentSmallKey;
                assets.small_text = currentSmallText;
            }

            pendingPresence = {
                details: currentDetails,
                state: currentState,
                assets: assets,
                timestamps: timestamps
            };
            lastUpdateTime = currentTime;
            mutex.release();
        } catch (e:Dynamic) {
            if (mutex != null) try { mutex.release(); } catch (err:Dynamic) {}
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
        if (!isEnabled) return;
        var detailsText:String = '$songName [${difficulty.toUpperCase()}]';
        var roundedAcc:Float = Math.round(accuracy * 100) / 100;
        var lKey:String = (iconKey != null && iconKey.length > 0) ? iconKey : "icon";
        var lText:String = (iconText != null) ? iconText : Version.versionString();

        if (isPaused) {
            var stateText = 'Paused | Score: $score | Misses: $misses | Acc: $roundedAcc%';
            changePresence(detailsText, stateText, "pause", false, 0, lKey, lText, 0, 0, null, true);
        } else {
            var stateText = 'Score: $score | Misses: $misses | Acc: $roundedAcc%';
            var remainingSecs:Float = Math.max(0, (duration - songPosition) / 1000.0);
            var endTime:Float = Sys.time() + remainingSecs;
            changePresence(detailsText, stateText, "playing", true, endTime, lKey, lText, 0, 0, null, false);
        }
    }

    public static function setMenuPresence(menuName:String, ?modIcon:String = "icon"):Void {
        currentElapsedSeconds = 0;
        changePresence("Main Menus", menuName, null, true, 0, modIcon);
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
            if (mutex != null) try { mutex.release(); } catch (err:Dynamic) {}
        }
        isInitialized = false;
        #elseif (hl && sys)
        isRunning = false;
        try {
            if (pipeOutput != null) pipeOutput.close();
            if (pipeInput != null) pipeInput.close();
            if (socket != null) socket.close();
        } catch (e:Dynamic) {}
        isInitialized = false;
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
        Logger.info('Discord RPC connected on C++ as $username', "discord");
    }

    private static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void {
        var msg = cast(message, String);
        Logger.warn('Discord RPC disconnected ($errorCode): $msg', "discord");
    }

    private static function onError(errorCode:Int, message:cpp.ConstCharStar):Void {
        var msg = cast(message, String);
        Logger.error('Discord RPC error ($errorCode): $msg', "discord");
    }
    #end
}