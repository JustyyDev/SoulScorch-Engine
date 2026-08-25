package soulscorch.scripting;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import soulscorch.gameplay.PlayState;
import soulscorch.graphics.shaders.ShaderManager;
import soulscorch.graphics.shaders.SoulShader;
import soulscorch.backend.system.modules.discord.DiscordRPC;
import soulscorch.backend.system.modules.github.GithubModule;
import soulscorch.backend.system.modules.discord.DiscordRichPresenceExtensions;
import soulscorch.backend.assets.AssetHelper;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.assets.Paths;
import soulscorch.backend.audio.Conductor;
import soulscorch.backend.system.EventBus;
import soulscorch.backend.system.XMSoul;
import soulscorch.backend.system.engine.Runtime;
import soulscorch.backend.system.engine.Version;
import soulscorch.backend.utils.ColorUtil;
import soulscorch.scripting.mod.ModLoader;
import soulscorch.scripting.mod.ModManager;
import soulscorch.scripting.mod.ModRegistry;

using StringTools;

class ScriptAPI {
    public static function install(target:ScriptInstance):Void {
        if (target == null) return;

        target.set("ScriptAPI", ScriptAPI);
        target.set("FlxG", FlxG);
        target.set("PlayState", PlayState);
        target.set("Runtime", Runtime);
        target.set("Version", Version);
        target.set("Conductor", Conductor);
        target.set("Paths", Paths);
        target.set("AssetHelper", AssetHelper);
        target.set("AssetResolver", AssetResolver);
        target.set("XMSoul", XMSoul);
        target.set("EventBus", EventBus);
        target.set("ModLoader", ModLoader);
        target.set("ModManager", ModManager);
        target.set("ModRegistry", ModRegistry);
        target.set("createShader", createShader);
        target.set("addShaderToCam", addShaderToCamera);
        target.set("removeShaderFromCam", removeShaderFromCamera);
        target.set("setShaderFloat", setShaderFloat);
        target.set("setShaderFloatArray", setShaderFloatArray);
        target.set("setShaderInt", setShaderInt);
        target.set("setShaderBool", setShaderBool);
        target.set("setSpriteShader", setSpriteShader);
        target.set("clearCameraShaders", clearCameraShaders);
        target.set("setDiscordPresence", setDiscordPresence);
        target.set("setDiscordEnabled", setDiscordEnabled);
        target.set("reloadDiscordConfig", reloadDiscordConfig);
        target.set("checkGitHubUpdates", checkGitHubUpdates);
        target.set("setChartEditorPresence", setChartEditorPresence);
        target.set("setScriptDebuggingPresence", setScriptDebuggingPresence);
        target.set("setLobbyPresence", setLobbyPresence);
        target.set("setAchievementsPresence", setAchievementsPresence);
        target.set("setMusicPlayerPresence", setMusicPlayerPresence);
        target.set("getColor", function(value:String, fallback:FlxColor = FlxColor.WHITE) return ColorUtil.fromHexSafe(value, fallback));
    }

    public static function createShader(name:String):Null<SoulShader> {
        if (name == null || name.trim().length == 0) return null;
        return ShaderManager.instance.getShader(name.trim());
    }

    public static function addShaderToCamera(shaderName:String, cameraName:String = "game"):Bool {
        var shader = createShader(shaderName);
        var camera = resolveCamera(cameraName);
        if (shader == null || camera == null) return false;
        ShaderManager.instance.addShader(shader, camera);
        return true;
    }

    public static function removeShaderFromCamera(shaderName:String, cameraName:String = "game"):Bool {
        var shader = ShaderManager.instance.getShader(shaderName);
        var camera = resolveCamera(cameraName);
        if (shader == null || camera == null) return false;
        ShaderManager.instance.removeShader(shader, camera);
        return true;
    }

    public static function setShaderFloat(shaderName:String, uniform:String, value:Float):Bool {
        var shader = ShaderManager.instance.getShader(shaderName);
        if (shader == null) return false;
        shader.setFloat(uniform, value);
        return true;
    }

    public static function setShaderFloatArray(shaderName:String, uniform:String, value:Array<Float>):Bool {
        var shader = ShaderManager.instance.getShader(shaderName);
        if (shader == null) return false;
        shader.setFloatArray(uniform, value);
        return true;
    }

    public static function setShaderInt(shaderName:String, uniform:String, value:Int):Bool {
        var shader = ShaderManager.instance.getShader(shaderName);
        if (shader == null) return false;
        shader.setInt(uniform, value);
        return true;
    }

    public static function setShaderBool(shaderName:String, uniform:String, value:Bool):Bool {
        var shader = ShaderManager.instance.getShader(shaderName);
        if (shader == null) return false;
        shader.setBool(uniform, value);
        return true;
    }

    public static function setSpriteShader(sprite:FlxSprite, shaderName:String):Bool {
        if (sprite == null) return false;
        var shader = createShader(shaderName);
        if (shader == null) return false;
        sprite.shader = shader;
        return true;
    }

    public static function clearCameraShaders(cameraName:String = "game"):Void {
        var camera = resolveCamera(cameraName);
        if (camera != null) camera.setFilters([]);
    }

    public static function resolveCamera(cameraName:String = "game"):FlxCamera {
        var game = PlayState.instance;
        var clean = cameraName == null ? "game" : cameraName.toLowerCase().trim();
        if (game == null) return FlxG.camera;
        return switch (clean) {
            case "hud", "camhud": game.camHUD;
            case "other", "camother": game.camOther;
            case "controls", "camcontrols": game.camControls;
            case "game", "camgame": game.camGame;
            default: FlxG.camera;
        };
    }

    public static function setDiscordPresence(details:String, state:String = "", largeImageKey:String = "icon", smallImageKey:String = ""):Void {
        DiscordRPC.changePresence(details, state, smallImageKey, false, 0, largeImageKey);
    }

    public static function setDiscordEnabled(enabled:Bool):Void {
        DiscordRPC.setEnabled(enabled);
    }

    public static function reloadDiscordConfig():Void {
        DiscordRPC.reloadConfig();
    }

    public static function checkGitHubUpdates():Void {
        if (GithubModule.instance != null) GithubModule.instance.checkLatestRelease();
    }

    public static function setChartEditorPresence(songName:String, currentStep:Int, bpm:Float):Void {
        DiscordRichPresenceExtensions.setChartEditorPresence(songName, currentStep, bpm);
    }

    public static function setScriptDebuggingPresence(scriptName:String):Void {
        DiscordRichPresenceExtensions.setScriptDebuggingPresence(scriptName);
    }

    public static function setLobbyPresence(lobbyName:String, players:Int, maxPlayers:Int, partyId:String):Void {
        DiscordRichPresenceExtensions.setLobbyPresence(lobbyName, players, maxPlayers, partyId);
    }

    public static function setAchievementsPresence(unlocked:Int, total:Int):Void {
        DiscordRichPresenceExtensions.setAchievementsPresence(unlocked, total);
    }

    public static function setMusicPlayerPresence(trackTitle:String, artistName:String):Void {
        DiscordRichPresenceExtensions.setMusicPlayerPresence(trackTitle, artistName);
    }
}
