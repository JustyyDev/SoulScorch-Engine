package soulscorch.backend;

import flixel.sound.FlxSound;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModManager;
import flixel.FlxG;
#if sys
import sys.FileSystem;
#end

class StemMixer {
    public var stems:Map<String, FlxSound> = new Map();
    public var masterVolume:Float = 1.0;
    public var missFilter:Float = 0.0;
    public function new() {}
    public function load(songId:String):Void { clear(); for (name in ["Inst", "Voices-Player", "Voices-Opponent", "SFX"]) { var path:String = ModManager.getPath('songs/$songId/song/$name.ogg'); #if sys if (FileSystem.exists(path)) stems.set(name, FlxG.sound.load(path)); #end } }
    public function play():Void for (sound in stems) sound.play();
    public function pause():Void for (sound in stems) sound.pause();
    public function stop():Void for (sound in stems) sound.stop();
    public function setVolume(name:String, volume:Float):Void { var sound:FlxSound = stems.get(name); if (sound != null) sound.volume = Math.max(0.0, Math.min(1.0, volume)) * masterVolume; }
    public function setMasterVolume(value:Float):Void { masterVolume = Math.max(0.0, Math.min(1.0, value)); for (name in stems.keys()) setVolume(name, stems.get(name).volume); }
    public function applyMissFilter(amount:Float):Void { missFilter = Math.max(0.0, Math.min(1.0, amount)); setVolume("Voices-Player", 1.0 - missFilter); }
    public function clear():Void { for (sound in stems) { sound.stop(); sound.destroy(); } stems.clear(); }
}
