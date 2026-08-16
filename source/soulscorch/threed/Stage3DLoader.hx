package soulscorch.threed;

import haxe.Json;
import openfl.geom.Vector3D;
import soulscorch.modding.ModManager;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef Stage3DConfig = { var skybox:String; var fogDensity:Float; var models:Array<String>; var cameraAnchor:Vector3D; }

class Stage3DLoader {
    public static function load(path:String):Null<Stage3DConfig> {
        var resolved:String = ModManager.getPath(path);
        #if sys
        if (resolved == null || !FileSystem.exists(resolved)) return null;
        try {
            return parse(File.getContent(resolved));
        } catch (error:Dynamic) {
            return null;
        }
        #else
        return null;
        #end
    }
    public static function parse(raw:String):Stage3DConfig {
        var root:Dynamic = Json.parse(raw); var anchor:Dynamic = Reflect.hasField(root, "cameraAnchor") ? Reflect.field(root, "cameraAnchor") : null; var point:Vector3D = new Vector3D();
        if (anchor != null) { point.x = number(anchor, "x", 0); point.y = number(anchor, "y", 0); point.z = number(anchor, "z", 0); }
        var modelList:Array<String> = []; var rawModels:Dynamic = Reflect.hasField(root, "models") ? Reflect.field(root, "models") : []; if (Std.isOfType(rawModels, Array)) for (model in (cast rawModels:Array<Dynamic>)) modelList.push(Std.string(model));
        return {skybox: fieldString(root, "skybox", ""), fogDensity: number(root, "fogDensity", 0), models: modelList, cameraAnchor: point};
    }
    private static function number(value:Dynamic, field:String, fallback:Float):Float return value != null && Reflect.hasField(value, field) ? Std.parseFloat(Std.string(Reflect.field(value, field))) : fallback;
    private static function fieldString(value:Dynamic, field:String, fallback:String):String return value != null && Reflect.hasField(value, field) ? Std.string(Reflect.field(value, field)) : fallback;
}
