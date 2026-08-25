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

    @:isVar public var modX(get, set):Float = 0.0;
    @:isVar public var modY(get, set):Float = 0.0;
    @:isVar public var modAngle(get, set):Float = 0.0;
    @:isVar public var modAlpha(get, set):Float = 1.0;

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

            receptors.push(receptor);
            add(receptor);
        }
    }

    public function clearReceptors():Void {
        while (receptors.length > 0) {
            var r = receptors.pop();
            if (r != null) {
                remove(r, true);
                FlxDestroyUtil.destroy(r);
            }
        }
    }

    public function changeSkin(newSkin:String):Void {
        if (newSkin == null || newSkin.trim().length == 0) return;
        currentSkin = newSkin.trim();

        for (i in 0...receptors.length) {
            var r = receptors[i];
            if (r != null) {
                r.loadReceptorSkin(currentSkin);
                r.playAnim("static", true);
            }
        }
    }

    public function updateLayout():Void {
        var len = receptors.length;
        for (i in 0...len) {
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
        var cleanDir = direction % keyCount;
        if (cleanDir < 0) cleanDir += keyCount;
        if (cleanDir >= 0 && cleanDir < receptors.length) {
            return receptors[cleanDir];
        }
        return null;
    }

    inline function get_x():Float return x;
    function set_x(val:Float):Float {
        x = val;
        updateLayout();
        return val;
    }

    inline function get_y():Float return y;
    function set_y(val:Float):Float {
        y = val;
        updateLayout();
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

    inline function get_modX():Float return modX;
    function set_modX(val:Float):Float {
        modX = val;
        updateLayout();
        return val;
    }

    inline function get_modY():Float return modY;
    function set_modY(val:Float):Float {
        modY = val;
        updateLayout();
        return val;
    }

    inline function get_modAngle():Float return modAngle;
    function set_modAngle(val:Float):Float {
        modAngle = val;
        updateLayout();
        return val;
    }

    inline function get_modAlpha():Float return modAlpha;
    function set_modAlpha(val:Float):Float {
        modAlpha = val;
        updateLayout();
        return val;
    }

    override public function destroy():Void {
        clearReceptors();
        receptors = [];
        super.destroy();
    }
}