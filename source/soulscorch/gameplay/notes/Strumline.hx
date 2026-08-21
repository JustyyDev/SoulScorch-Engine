package soulscorch.gameplay.notes;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;
import soulscorch.gameplay.notes.StrumArrow;

using StringTools;

class Strumline extends FlxTypedGroup<StrumArrow> {
    public var receptors:Array<StrumArrow> = [];
    public var isPlayer:Bool = false;
    public var downscroll:Bool = false;
    public var keyCount:Int = 4;
    public var currentSkin:String = "NOTE_assets";

    @:isVar public var x(get, set):Float = 0.0;
    @:isVar public var y(get, set):Float = 0.0;
    @:isVar public var alpha(get, set):Float = 1.0;
    @:isVar public var angle(get, set):Float = 0.0;
    @:isVar public var spacing(get, set):Float = 112.0;

    public var modX:Float = 0.0;
    public var modY:Float = 0.0;
    public var modAngle:Float = 0.0;
    public var modAlpha:Float = 1.0;
    public var modScaleX:Float = 1.0;
    public var modScaleY:Float = 1.0;

    public static inline var STRUM_SPACING:Float = 112.0;

    public function new(
        x:Float,
        y:Float,
        isPlayer:Bool = false,
        downscroll:Bool = false,
        keyCount:Int = 4,
        ?skin:String = "NOTE_assets",
        ?spacing:Float = 112.0
    ) {
        super();
        this.keyCount = (keyCount > 0) ? keyCount : 4;
        this.isPlayer = isPlayer;
        this.downscroll = downscroll;
        this.currentSkin = (skin != null && skin.trim().length > 0) ? skin.trim() : "NOTE_assets";
        this.spacing = (spacing != null && spacing > 0) ? spacing : STRUM_SPACING;

        this.x = x;
        this.y = y;

        createReceptors(this.currentSkin);
    }

    public function createReceptors(?skin:String):Void {
        clearReceptors();

        if (skin != null && skin.trim().length > 0) {
            currentSkin = skin.trim();
        }

        for (i in 0...keyCount) {
            var posX:Float = this.x + (i * this.spacing) + modX;
            var posY:Float = this.y + modY;

            var receptor = new StrumArrow(posX, posY, i, isPlayer, downscroll, currentSkin);
            receptor.alpha = this.alpha * this.modAlpha;
            receptor.visible = this.visible;
            receptor.angle = this.angle + this.modAngle;
            receptor.scale.x *= this.modScaleX;
            receptor.scale.y *= this.modScaleY;

            receptors.push(receptor);
            add(receptor);
        }
    }

    public function clearReceptors():Void {
        while (receptors.length > 0) {
            var r = receptors.pop();
            remove(r, true);
            FlxDestroyUtil.destroy(r);
        }
    }

    public function changeSkin(newSkin:String):Void {
        if (newSkin == null || newSkin.trim().length == 0 || newSkin == currentSkin) return;
        currentSkin = newSkin.trim();

        for (r in receptors) {
            if (r != null) {
                r.loadReceptorSkin(currentSkin);
                r.playAnim("static", true);
            }
        }
    }

    public function updateLayout():Void {
        for (i in 0...receptors.length) {
            var r = receptors[i];
            if (r != null) {
                r.baseX = this.x + (i * this.spacing);
                r.baseY = this.y;
                r.x = r.baseX + modX;
                r.y = r.baseY + modY;
                r.angle = this.angle + modAngle;
                r.alpha = this.alpha * modAlpha;
                r.visible = this.visible;
            }
        }
    }

    public function playStrumAnim(direction:Int, animName:String, force:Bool = true):Void {
        var r = getReceptor(direction);
        if (r != null) r.playAnim(animName, force);
    }

    public function press(direction:Int):Void {
        var r = getReceptor(direction);
        if (r != null) r.playAnim("pressed", true);
    }

    public function release(direction:Int):Void {
        var r = getReceptor(direction);
        if (r != null) r.playAnim("static", true);
    }

    public function confirm(direction:Int, ?resetDuration:Float = 0.15):Void {
        var r = getReceptor(direction);
        if (r != null) {
            r.playAnim("confirm", true);
            r.resetAnim = resetDuration;
        }
    }

    public inline function getReceptor(direction:Int):Null<StrumArrow> {
        if (direction >= 0 && direction < receptors.length) {
            return receptors[direction];
        }
        return null;
    }

    inline function get_x():Float return x;
    function set_x(val:Float):Float {
        x = val;
        for (i in 0...receptors.length) {
            if (receptors[i] != null) {
                receptors[i].baseX = val + (i * spacing);
                receptors[i].x = receptors[i].baseX + modX;
            }
        }
        return val;
    }

    inline function get_y():Float return y;
    function set_y(val:Float):Float {
        y = val;
        for (r in receptors) {
            if (r != null) {
                r.baseY = val;
                r.y = val + modY;
            }
        }
        return val;
    }

    inline function get_alpha():Float return alpha;
    function set_alpha(val:Float):Float {
        alpha = val;
        for (r in receptors) {
            if (r != null) r.alpha = val * modAlpha;
        }
        return val;
    }

    inline function get_angle():Float return angle;
    function set_angle(val:Float):Float {
        angle = val;
        for (r in receptors) {
            if (r != null) r.angle = val + modAngle;
        }
        return val;
    }

    inline function get_spacing():Float return spacing;
    function set_spacing(val:Float):Float {
        spacing = val;
        updateLayout();
        return val;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (modX != 0 || modY != 0 || modAngle != 0 || modAlpha != 1.0 || modScaleX != 1.0 || modScaleY != 1.0) {
            for (i in 0...receptors.length) {
                var r = receptors[i];
                if (r != null) {
                    r.x = (this.x + (i * spacing)) + modX;
                    r.y = this.y + modY;
                    r.angle = this.angle + modAngle;
                    r.alpha = this.alpha * modAlpha;
                }
            }
        }
    }

    override public function destroy():Void {
        clearReceptors();
        receptors = [];
        super.destroy();
    }
}