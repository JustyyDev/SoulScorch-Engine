package flixel.sound;

import flixel.FlxBasic;
import flixel.FlxG;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.media.SoundTransform;
import openfl.events.Event;

/**
 * Custom FlxSound implementation designed to prevent audio-visual desync
 * by querying native hardware playback positions where available.
 */
class FlxSound extends FlxBasic {
    public var x:Float = 0;
    public var y:Float = 0;
    public var playing:Bool = false;
    public var volume(default, set):Float = 1.0;
    public var length(get, never):Float;

    @:noCompletion private var _sound:Sound;
    @:noCompletion private var _channel:SoundChannel;
    @:noCompletion private var _transform:SoundTransform;
    @:noCompletion private var _volumeAdjust:Float = 1.0;

    public var time(get, set):Float;
    private var _time:Float = 0;

    public function new() {
        super();
        _transform = new SoundTransform();
    }

    public function loadEmbedded(EmbeddedSound:String, Looped:Bool = false, AutoDestroy:Bool = false):FlxSound {
        _sound = openfl.Assets.getSound(EmbeddedSound);
        return this;
    }

    public function play(ForceRestart:Bool = false, StartTime:Float = 0.0, ?EndTime:Float):FlxSound {
        if (!active) return this;
        if (playing && !ForceRestart) return this;

        if (playing) stop();
        
        _time = StartTime;
        playing = true;

        if (_sound != null) {
            _channel = _sound.play(_time, 0, _transform);
            if (_channel != null) {
                _channel.addEventListener(Event.SOUND_COMPLETE, stopped);
            }
        }
        return this;
    }

    public function pause():Void {
        if (!playing) return;
        if (_channel != null) {
            _time = _channel.position;
            _channel.stop();
        }
        playing = false;
    }

    public function resume():Void {
        if (playing) return;
        play(false, _time);
    }

    public function stop():Void {
        if (!playing) return;
        if (_channel != null) {
            _channel.stop();
            _channel.removeEventListener(Event.SOUND_COMPLETE, stopped);
        }
        playing = false;
        _time = 0;
    }

    private function stopped(?event:Event):Void {
        if (playing) {
            stop();
        }
    }

    override public function update(elapsed:Float):Void {
        if (playing && _channel != null) {
            // Instead of accumulating elapsed time, sync _time to the actual hardware buffer
            _time = _channel.position;
        }
        super.update(elapsed);
    }

    private function get_time():Float {
        if (playing && _channel != null) {
            #if (desktop || web)
            // Query the exact hardware position if active
            return _channel.position;
            #else
            return _time;
            #end
        }
        return _time;
    }

    private function set_time(Value:Float):Float {
        _time = Value;
        if (playing && _channel != null) {
            _channel.stop();
            _channel.removeEventListener(Event.SOUND_COMPLETE, stopped);
            _channel = _sound.play(_time, 0, _transform);
            if (_channel != null) {
                _channel.addEventListener(Event.SOUND_COMPLETE, stopped);
            }
        }
        return _time;
    }

    private function get_length():Float {
        if (_sound != null) return _sound.length;
        return 0;
    }

    private function set_volume(Value:Float):Float {
        volume = FlxMath.bound(Value, 0.0, 1.0);
        if (_transform != null) {
            _transform.volume = volume * _volumeAdjust;
            if (_channel != null) {
                _channel.soundTransform = _transform;
            }
        }
        return volume;
    }
}