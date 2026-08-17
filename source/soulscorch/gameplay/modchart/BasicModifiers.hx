package soulscorch.gameplay.modchart;

import soulscorch.gameplay.modchart.ModchartTypes.ModTarget;
import soulscorch.gameplay.modchart.ModchartTypes.RenderTransform;

// --- DRUNK (Wave displacement along the X-axis) ---
class DrunkModifier extends Modifier {
    public function new() super("drunk");

    override public function applyStrum(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float):Void {
        var val = getValue(target, lane);
        if (val == 0.0) return;
        var time = (songPosition * 0.003) + (lane * 0.4);
        transform.x += Math.cos(time) * (val * 56.0);
    }

    override public function applyNote(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float, noteDist:Float):Void {
        var val = getValue(target, lane);
        if (val == 0.0) return;
        var time = (songPosition * 0.003) + (lane * 0.4) + (noteDist * 0.005);
        transform.x += Math.cos(time) * (val * 56.0);
    }
}

// --- TIPSY (Vertical rolling bounce wave) ---
class TipsyModifier extends Modifier {
    public function new() super("tipsy");

    override public function applyStrum(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float):Void {
        var val = getValue(target, lane);
        if (val == 0.0) return;
        var time = (songPosition * 0.0035) + (lane * 1.2);
        transform.y += Math.cos(time) * (val * 40.0);
    }

    override public function applyNote(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float, noteDist:Float):Void {
        var val = getValue(target, lane);
        if (val == 0.0) return;
        var time = (songPosition * 0.0035) + (lane * 1.2) + (noteDist * 0.004);
        transform.y += Math.cos(time) * (val * 40.0);
    }
}

// --- TORNADO (Horizontal lane swirling / funnel effect) ---
class TornadoModifier extends Modifier {
    public function new() super("tornado");

    override public function applyNote(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float, noteDist:Float):Void {
        var val = getValue(target, lane);
        if (val == 0.0) return;
        var progress = (noteDist * 0.003) + (lane * 0.5);
        transform.x += Math.sin(progress) * (val * 64.0);
    }
}

// --- BEAT (Heartbeat pulse per crochet beat) ---
class BeatModifier extends Modifier {
    public function new() super("beat");

    override public function applyStrum(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float):Void {
        var val = getValue(target, lane);
        if (val == 0.0) return;

        var beatProgress = (songPosition * 0.001 * 2.5) % 1.0;
        if (beatProgress < 0) beatProgress += 1.0;
        var shift = Math.sin(beatProgress * Math.PI) * (1.0 - beatProgress);
        transform.x += (lane % 2 == 0 ? -1 : 1) * shift * (val * 40.0);
    }
}

// --- BUMPY (Z-axis / scale ripples) ---
class BumpyModifier extends Modifier {
    public function new() super("bumpy");

    override public function applyNote(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float, noteDist:Float):Void {
        var val = getValue(target, lane);
        if (val == 0.0) return;
        var wave = Math.sin((noteDist * 0.01) + (songPosition * 0.004));
        transform.y += wave * (val * 30.0);
        transform.scaleX += wave * (val * 0.2);
        transform.scaleY += wave * (val * 0.2);
    }
}

// --- REVERSE, INVERT, FLIP (Lane layout manipulations) ---
class LaneModifier extends Modifier {
    public function new() super("laneMods");

    override public function applyStrum(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float):Void {
        var reverse = getValue(target, lane);
        if (reverse != 0.0) {
            transform.y += reverse * 450.0;
        }
    }

    override public function applyNote(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float, noteDist:Float):Void {
        var reverse = getValue(target, lane);
        if (reverse != 0.0) {
            transform.y += reverse * (450.0 - (noteDist * 2.0));
        }
    }
}

// --- TRANSFORM MODIFIERS (Direct X, Y, Z, Angle, Alpha offsets) ---
class TransformModifier extends Modifier {
    public var type:String;

    public function new(type:String) {
        super(type);
        this.type = type;
    }

    override public function applyStrum(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float):Void {
        var val = getValue(target, lane);
        if (val == 0.0) return;

        switch (type) {
            case "x": transform.x += val;
            case "y": transform.y += val;
            case "z": transform.z += val;
            case "angle": transform.angle += val;
            case "alpha": transform.alpha *= (1.0 - val);
            case "scaleX": transform.scaleX *= val;
            case "scaleY": transform.scaleY *= val;
            case "skewX": transform.skewX += val;
            case "skewY": transform.skewY += val;
        }
    }

    override public function applyNote(transform:RenderTransform, lane:Int, target:ModTarget, songPosition:Float, noteDist:Float):Void {
        applyStrum(transform, lane, target, songPosition);
    }
}