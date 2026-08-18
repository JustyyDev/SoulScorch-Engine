package soulscorch.gameplay.modchart;

import flixel.math.FlxMath;

class ModchartWorkspaceMath {
    public static function applyModifiers(
        baseX:Float, 
        baseY:Float, 
        lane:Int, 
        songTime:Float, 
        drunkVal:Float, 
        tipsyVal:Float, 
        beatVal:Float, 
        confusionVal:Float, 
        stealthVal:Float
    ):{x:Float, y:Float, angle:Float, alpha:Float} {
        var xOffset:Float = 0.0;
        var yOffset:Float = 0.0;
        var angleOffset:Float = 0.0;
        var alphaOffset:Float = 1.0;

        var timeSec = songTime * 0.001;

        // 1. Drunk (Horizontal sine wave across lanes)
        if (drunkVal != 0) {
            xOffset += Math.sin((timeSec * 3.0) + (lane * 0.7)) * (drunkVal * 40.0);
        }

        // 2. Tipsy (Vertical sine wave stagger)
        if (tipsyVal != 0) {
            yOffset += Math.cos((timeSec * 4.0) + (lane * 1.2)) * (tipsyVal * 30.0);
        }

        // 3. Beat Bumping
        if (beatVal != 0) {
            var beatProgress = (songTime % 500) / 500.0;
            var bump = Math.sin(beatProgress * Math.PI) * (beatVal * 25.0);
            yOffset += (lane % 2 == 0) ? bump : -bump;
        }

        // 4. Confusion (Angle rotation)
        if (confusionVal != 0) {
            angleOffset += (timeSec * confusionVal * 120.0) % 360.0;
        }

        // 5. Stealth (Receptor transparency)
        if (stealthVal != 0) {
            alphaOffset = Math.max(0.0, 1.0 - stealthVal);
        }

        return {
            x: baseX + xOffset,
            y: baseY + yOffset,
            angle: angleOffset,
            alpha: alphaOffset
        };
    }
}