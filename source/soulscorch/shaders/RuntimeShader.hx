package soulscorch.shaders;

import flixel.system.FlxAssets.FlxShader;
import openfl.display.BitmapData;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModLoader;

class RuntimeShader extends FlxShader {
    public var shaderName:String;

    static inline var DEFAULT_VERTEX:String = "
        #pragma header
        void main(void) {
            #pragma body
        }
    ";

    static inline var DEFAULT_FRAGMENT:String = "
        #pragma header
        void main(void) {
            #pragma body
        }
    ";

    public function new(?fragSource:String, ?vertSource:String, name:String = "RuntimeShader") {
        this.shaderName = name;
        var fSource:String = fragSource != null && fragSource != "" ? fragSource : DEFAULT_FRAGMENT;
        var vSource:String = vertSource != null && vertSource != "" ? vertSource : DEFAULT_VERTEX;

        glFragmentSource = fSource;
        glVertexSource = vSource;

        super();
    }

    public static function fromFile(fragPath:String, ?vertPath:String):RuntimeShader {
        var resFrag = ModLoader.getPath(fragPath);
        var resVert = vertPath != null ? ModLoader.getPath(vertPath) : null;

        var fragCode = AssetResolver.exists(resFrag) ? AssetResolver.getText(resFrag) : DEFAULT_FRAGMENT;
        var vertCode = (resVert != null && AssetResolver.exists(resVert)) ? AssetResolver.getText(resVert) : DEFAULT_VERTEX;

        return new RuntimeShader(fragCode, vertCode, fragPath);
    }

    public function setFloat(name:String, value:Float):Void {
        var prop:Dynamic = Reflect.field(data, name);
        if (prop != null && Reflect.hasField(prop, "value")) {
            prop.value = [value];
        }
    }

    public function setFloatArray(name:String, values:Array<Float>):Void {
        var prop:Dynamic = Reflect.field(data, name);
        if (prop != null && Reflect.hasField(prop, "value")) {
            prop.value = values;
        }
    }

    public function setInt(name:String, value:Int):Void {
        var prop:Dynamic = Reflect.field(data, name);
        if (prop != null && Reflect.hasField(prop, "value")) {
            prop.value = [value];
        }
    }

    public function setBool(name:String, value:Bool):Void {
        var prop:Dynamic = Reflect.field(data, name);
        if (prop != null && Reflect.hasField(prop, "value")) {
            prop.value = [value];
        }
    }

    public function setSampler2D(name:String, bitmap:BitmapData):Void {
        var prop:Dynamic = Reflect.field(data, name);
        if (prop != null && Reflect.hasField(prop, "input")) {
            prop.input = bitmap;
        }
    }
}