package soulscorch.ui.menus.states;

import flixel.FlxG;
import flixel.util.FlxColor;
import soulscorch.backend.audio.Conductor;
import soulscorch.graphics.shaders.SoulShader;
import soulscorch.graphics.shaders.ShaderManager;

/**
 * Built-in title-screen shader presets. Centralizes the cool default effects
 * (boot glitch, hologram FMOD/engine logo, scanlines, vignette pulse) so the
 * TitleState and mod scripts can toggle them with one call.
 */
class TitleShaders {
    public static var bootGlitch:SoulShader;
    public static var hologram:SoulShader;
    public static var scanlines:SoulShader;
    public static var vignette:SoulShader;

    public static var initialized:Bool = false;

    public static function init():Void {
        if (initialized) return;

        bootGlitch = new SoulShader("engine/title/bootGlitch");
        hologram = new SoulShader("engine/title/hologram");
        scanlines = new SoulShader("engine/title/scanlines");
        vignette = new SoulShader("engine/title/vignettePulse");

        hologram.setFloatArray("uTint", [0.4, 0.8, 1.0]);
        vignette.setFloatArray("uColor", [0.5, 0.3, 1.0]);

        initialized = true;
    }

    /** Apply the global title atmosphere (scanlines + vignette) to camGame. */
    public static function applyAtmosphere(cam:flixel.FlxCamera):Void {
        if (!initialized) init();
        ShaderManager.instance.addShader(scanlines, cam);
        ShaderManager.instance.addShader(vignette, cam);
    }

    /** Hologram effect for the engine/FMOD logo sprite. */
    public static function applyHologram(spr:flixel.FlxSprite):Void {
        if (!initialized) init();
        spr.shader = hologram;
    }

    public static function update(elapsed:Float, beat:Float):Void {
        if (!initialized) return;
        var beatPulse = Math.abs(Math.sin(beat * Math.PI));

        if (scanlines != null) {
            scanlines.setFloat("uBeat", beatPulse);
            scanlines.setFloat("uIntensity", 1.0);
        }
        if (vignette != null) {
            vignette.setFloat("uBeat", beatPulse);
        }
        if (hologram != null) {
            hologram.setFloat("uIntensity", 1.0);
        }
    }

    public static function setBootProgress(progress:Float):Void {
        if (bootGlitch != null) bootGlitch.setFloat("uProgress", progress);
    }

    public static function clear():Void {
        if (!initialized) return;
        ShaderManager.instance.removeShader(scanlines);
        ShaderManager.instance.removeShader(vignette);
        initialized = false;
    }
}
