package soulscorch.system;

import openfl.media.SoundMixer;
import openfl.utils.ByteArray;

class AudioAnalyzer {
    public var bass:Float = 0;
    public var mid:Float = 0;
    public var treble:Float = 0;
    public var rawData:Array<Float> = [];

    private var bytes:ByteArray;

    public function new() {
        bytes = new ByteArray();
        for (i in 0...256) rawData.push(0);
    }

    public function update():Void {
        try {
            SoundMixer.computeSpectrum(bytes, true, 0);
        } catch (e:Dynamic) {
            return;
        }

        var totalBass:Float = 0;
        var totalMid:Float = 0;
        var totalTreble:Float = 0;

        for (i in 0...256) {
            var value:Float = bytes.readFloat();
            rawData[i] = value;

            if (i < 85) {
                totalBass += Math.abs(value);
            } else if (i < 170) {
                totalMid += Math.abs(value);
            } else {
                totalTreble += Math.abs(value);
            }
        }

        bass = totalBass / 85;
        mid = totalMid / 85;
        treble = totalTreble / 86;
    }
}