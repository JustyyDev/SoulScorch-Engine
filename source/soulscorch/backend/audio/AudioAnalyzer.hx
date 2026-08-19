package soulscorch.backend.audio;

import openfl.media.SoundMixer;
import openfl.utils.ByteArray;
import soulscorch.backend.system.EventBus;

class AudioAnalyzer {
    public var bass:Float = 0;
    public var mid:Float = 0;
    public var treble:Float = 0;
    public var rawData:Array<Float> = [];

    private var bytes:ByteArray;
    private var beatCooldown:Float = 0;

    public function new() {
        bytes = new ByteArray();
        for (i in 0...256) rawData.push(0);
    }

    public function update(?elapsed:Float = 0.0):Void {
        try {
            var mixer:Dynamic = SoundMixer;
            var computeSpectrum:Dynamic = Reflect.field(mixer, "computeSpectrum");
            if (computeSpectrum == null) return;

            bytes.position = 0;
            Reflect.callMethod(mixer, computeSpectrum, [bytes, true, 0]);
            bytes.position = 0;
        } catch (e:Dynamic) {
            return;
        }

        if (bytes.length < 1024) return;

        var totalBass:Float = 0;
        var totalMid:Float = 0;
        var totalTreble:Float = 0;

        for (i in 0...256) {
            var value:Float = (bytes.bytesAvailable >= 4) ? bytes.readFloat() : 0.0;
            rawData[i] = value;

            if (i < 85) {
                totalBass += Math.abs(value);
            } else if (i < 170) {
                totalMid += Math.abs(value);
            } else {
                totalTreble += Math.abs(value);
            }
        }

        bass = totalBass / 85.0;
        mid = totalMid / 85.0;
        treble = totalTreble / 86.0;

        if (beatCooldown > 0) beatCooldown -= elapsed;

        if (bass > 0.6 && beatCooldown <= 0) {
            beatCooldown = 0.12;
            dispatchBeat();
        }
    }

    private function dispatchBeat():Void {
        try {
            var bus:Dynamic = EventBus;
            if (Reflect.hasField(bus, "publish")) {
                bus.publish("audio/beat", {bass: bass, mid: mid, treble: treble});
            } else if (Reflect.hasField(bus, "emit")) {
                bus.emit("audio/beat", {bass: bass, mid: mid, treble: treble});
            }
        } catch (e:Dynamic) {}
    }
}