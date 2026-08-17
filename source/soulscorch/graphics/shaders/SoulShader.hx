package soulscorch.system;

import flixel.system.FlxAssets.FlxShader;
import openfl.display.BitmapData;
import soulscorch.assets.AssetResolver;
import soulscorch.modding.ModLoader;

class SoulShader extends FlxShader {
    public var shaderName:String = "SoulShader";

    public function new(fragFile:String = "", vertFile:String = "") {
        var fragSource = "";
        var vertSource = "";

        if (fragFile != "") {
            var path = ModLoader.getPath('assets/shaders/$fragFile.frag');
            if (AssetResolver.exists(path)) fragSource = AssetResolver.getText(path);
        }
        if (vertFile != "") {
            var path = ModLoader.getPath('assets/shaders/$vertFile.vert');
            if (AssetResolver.exists(path)) vertSource = AssetResolver.getText(path);
        }

        // Auto-inject OpenFL/Flixel standard header if #pragma header is used in .frag/.vert
        if (fragSource != "") {
            this.glFragmentSource = expandPragmaHeader(fragSource);
            this.shaderName = fragFile;
        }
        if (vertSource != "") {
            this.glVertexSource = expandPragmaHeader(vertSource);
        }

        super();
    }

    // 1. Texture / Sampler2D support (Crucial for noise textures, LUTs, and masks)
    public function setSampler2D(name:String, bitmap:BitmapData):Void {
        if (Reflect.hasField(this.data, name)) {
            Reflect.field(this.data, name).input = bitmap;
        }
    }

    // 2. Uniform Getters (Allows SoulScript / HScript to tween values smoothly)
    public function getFloat(name:String):Float {
        if (Reflect.hasField(this.data, name)) {
            var val:Array<Float> = Reflect.field(this.data, name).value;
            if (val != null && val.length > 0) return val[0];
        }
        return 0.0;
    }

    public function setFloat(name:String, value:Float):Void {
        if (Reflect.hasField(this.data, name)) {
            Reflect.field(this.data, name).value = [value];
        }
    }

    public function setFloatArray(name:String, value:Array<Float>):Void {
        if (Reflect.hasField(this.data, name)) {
            Reflect.field(this.data, name).value = value;
        }
    }

    public function setInt(name:String, value:Int):Void {
        if (Reflect.hasField(this.data, name)) {
            Reflect.field(this.data, name).value = [value];
        }
    }

    public function setBool(name:String, value:Bool):Void {
        if (Reflect.hasField(this.data, name)) {
            Reflect.field(this.data, name).value = [value];
        }
    }

    private static function expandPragmaHeader(src:String):String {
        if (src.indexOf("#pragma header") != -1) {
            var header = "
                #ifdef GL_ES
                precision mediump float;
                #endif
                varying vec2 openfl_TextureCoordv;
                varying vec4 openfl_Alphav;
                varying vec4 openfl_ColorMultiplierv;
                varying vec4 openfl_ColorOffsetv;
                uniform sampler2D bitmap;
                uniform bool openfl_HasColorTransform;
                vec4 flixel_texture2D(sampler2D bitmap, vec2 coord) {
                    vec4 color = texture2D(bitmap, coord);
                    if (!openfl_HasColorTransform) {
                        return color;
                    }
                    if (color.a == 0.0) {
                        return vec4(0.0, 0.0, 0.0, 0.0);
                    }
                    vec4 transformed = color * openfl_ColorMultiplierv + openfl_ColorOffsetv;
                    return transformed;
                }
            ";
            return StringTools.replace(src, "#pragma header", header);
        }
        return src;
    }
}