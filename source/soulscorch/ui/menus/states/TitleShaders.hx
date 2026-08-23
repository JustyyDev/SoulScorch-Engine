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

        try {
            hologram.setFloatArray("uTint", [0.4, 0.8, 1.0]);
        } catch (e:Dynamic) {
            // ignore missing uniform until shader is compiled
        }
        try {
            vignette.setFloatArray("uColor", [0.5, 0.3, 1.0]);
        } catch (e:Dynamic) {
        }

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
            try { scanlines.setFloat("uBeat", beatPulse); } catch (_) {}
            try { scanlines.setFloat("uIntensity", 1.0); } catch (_) {}
        }
        if (vignette != null) {
            try { vignette.setFloat("uBeat", beatPulse); } catch (_) {}
        }
        if (hologram != null) {
            try { hologram.setFloat("uIntensity", 1.0); } catch (_) {}
        }
    }

    public static function setBootProgress(progress:Float):Void {
        if (bootGlitch != null) {
            try { bootGlitch.setFloat("uProgress", progress); } catch (_) {}
        }
    }

    public static function clear():Void {
        if (!initialized) return;
        ShaderManager.instance.removeShader(scanlines);
        ShaderManager.instance.removeShader(vignette);
        initialized = false;
    }
}
