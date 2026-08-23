package soulscorch.graphics.shaders;

import flixel.FlxG;
import flixel.system.FlxAssets.FlxShader;
import openfl.display.BitmapData;
import openfl.filters.ShaderFilter;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.backend.utils.Logger;

using StringTools;

@:access(openfl.display.Shader)
class SoulShader extends FlxShader {
    public var shaderName:String = "SoulShader";
    public var filter(get, null):ShaderFilter;
    private var _cachedFilter:ShaderFilter;

    public inline function get_filter():ShaderFilter {
        if (_cachedFilter == null) {
            _cachedFilter = new ShaderFilter(this);
        }
        return _cachedFilter;
    }

    public static inline var DEFAULT_VERTEX:String = "
        #pragma header
        void main(void) {
            #pragma body
        }
    ";

    public static inline var DEFAULT_FRAGMENT:String = "
        #pragma header
        void main(void) {
            #pragma body
        }
    ";

    public function new(fragFile:String = "", vertFile:String = "") {
        var fragSource:String = "";
        var vertSource:String = "";

        if (fragFile != null && fragFile.trim().length > 0) {
            var rawFrag = fragFile.trim();
            if (rawFrag.endsWith(".frag")) rawFrag = rawFrag.substr(0, rawFrag.length - 5);

            var pathCandidates = [
                'shaders/$rawFrag.frag',
                '$rawFrag.frag',
                'assets/shaders/$rawFrag.frag',
                'assets/preload/shaders/$rawFrag.frag',
                'data/shaders/$rawFrag.frag'
            ];

            for (p in pathCandidates) {
                var text = AssetResolver.getText(p);
                if (text != null && text.length > 0) {
                    fragSource = text;
                    this.shaderName = rawFrag;
                    break;
                }
            }
        }

        if (vertFile != null && vertFile.trim().length > 0) {
            var rawVert = vertFile.trim();
            if (rawVert.endsWith(".vert")) rawVert = rawVert.substr(0, rawVert.length - 5);

            var pathCandidates = [
                'shaders/$rawVert.vert',
                '$rawVert.vert',
                'assets/shaders/$rawVert.vert',
                'assets/preload/shaders/$rawVert.vert',
                'data/shaders/$rawVert.vert'
            ];

            for (p in pathCandidates) {
                var text = AssetResolver.getText(p);
                if (text != null && text.length > 0) {
                    vertSource = text;
                    break;
                }
            }
        }

        var finalFrag = (fragSource != "") ? fragSource : DEFAULT_FRAGMENT;
        var finalVert = (vertSource != "") ? vertSource : DEFAULT_VERTEX;

        this.glFragmentSource = expandPragmas(finalFrag, true);
        this.glVertexSource = expandPragmas(finalVert, false);

        super();

        __isGenerated = false;
        __initGL();

        setFloatArray("iResolution", [FlxG.width, FlxG.height]);
        setFloat("iTime", 0.0);
        setFloat("u_time", 0.0);
        setFloat("time", 0.0);
    }

    @:noCompletion
    override function __initGL():Void {
        __isGenerated = false;
        super.__initGL();
    }

    public function update(elapsed:Float):Void {
        var cur = getFloat("iTime");
        var next = cur + elapsed;
        setFloat("iTime", next);
        setFloat("u_time", next);
        setFloat("time", next);

        if (FlxG.mouse != null) {
            setFloatArray("iMouse", [FlxG.mouse.x, FlxG.mouse.y, FlxG.mouse.justPressed ? 1.0 : 0.0, 0.0]);
        }
    }

    public function setSampler2D(name:String, bitmap:BitmapData):Void {
        if (this.data == null) return;
        var prop:Dynamic = Reflect.field(this.data, name);
        if (prop != null) {
            prop.input = bitmap;
        }
    }

    public function getFloat(name:String):Float {
        if (this.data == null) return 0.0;
        var prop:Dynamic = Reflect.field(this.data, name);
        if (prop != null && prop.value != null && prop.value.length > 0) {
            return prop.value[0];
        }
        return 0.0;
    }

    public function setFloat(name:String, value:Float):Void {
        if (this.data == null) return;
        var prop:Dynamic = Reflect.field(this.data, name);
        if (prop != null) {
            prop.value = [value];
        }
    }

    public function setFloatArray(name:String, value:Array<Float>):Void {
        if (this.data == null) return;
        var prop:Dynamic = Reflect.field(this.data, name);
        if (prop != null) {
            prop.value = value;
        }
    }

    public function setInt(name:String, value:Int):Void {
        if (this.data == null) return;
        var prop:Dynamic = Reflect.field(this.data, name);
        if (prop != null) {
            prop.value = [value];
        }
    }

    public function setBool(name:String, value:Bool):Void {
        if (this.data == null) return;
        var prop:Dynamic = Reflect.field(this.data, name);
        if (prop != null) {
            prop.value = [value];
        }
    }

    // Dynamic uniform access so scripts can do: shader.redOff = [x, y];
    public function __setField(name:String, value:Dynamic):Bool {
        if (this.data != null) {
            var prop:Dynamic = Reflect.field(this.data, name);
            if (prop != null) {
                if (Std.isOfType(value, Array)) {
                    prop.value = value;
                } else if (Std.isOfType(value, Float) || Std.isOfType(value, Int) || Std.isOfType(value, Bool)) {
                    prop.value = [value];
                } else if (Std.isOfType(value, BitmapData)) {
                    prop.input = value;
                } else {
                    prop.value = value;
                }
                return true;
            }
        }
        return false;
    }

    public function __getField(name:String):Dynamic {
        if (this.data != null) {
            var prop:Dynamic = Reflect.field(this.data, name);
            if (prop != null) return prop.value;
        }
        return null;
    }

    // Convenience helpers so scripts can do: shader.addTo(camGame); shader.removeFrom(camHUD);
    public function addTo(camera:flixel.FlxCamera):Void {
        soulscorch.graphics.shaders.ShaderManager.instance.addShader(this, camera);
    }

    public function removeFrom(camera:flixel.FlxCamera):Void {
        soulscorch.graphics.shaders.ShaderManager.instance.removeShader(this, camera);
    }

    public static function expandPragmas(src:String, isFragment:Bool):String {
        var header = isFragment ? "
            varying float openfl_Alphav;
            varying vec4 openfl_ColorMultiplierv;
            varying vec4 openfl_ColorOffsetv;
            varying vec2 openfl_TextureCoordv;

            uniform bool hasTransform;
            uniform bool hasColorTransform;
            uniform sampler2D bitmap;

            uniform float iTime;
            uniform float u_time;
            uniform float time;
            uniform vec2 iResolution;
            uniform vec4 iMouse;

            vec4 flixel_texture2D(sampler2D source, vec2 coord) {
                vec4 color = texture2D(source, coord);
                if (!hasTransform) return color;
                if (color.a == 0.0) return vec4(0.0);
                if (!hasColorTransform) return color * openfl_Alphav;

                color = vec4(color.rgb / color.a, color.a);
                mat4 colorMultiplier = mat4(0.0);
                colorMultiplier[0][0] = openfl_ColorMultiplierv.x;
                colorMultiplier[1][1] = openfl_ColorMultiplierv.y;
                colorMultiplier[2][2] = openfl_ColorMultiplierv.z;
                colorMultiplier[3][3] = openfl_ColorMultiplierv.w;
                color = clamp(openfl_ColorOffsetv + color * colorMultiplier, 0.0, 1.0);

                if (color.a <= 0.0) return vec4(0.0);
                return vec4(color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);
            }

            vec2 getCamPos(vec2 uv) {
                return uv;
            }

            vec4 textureCam(sampler2D source, vec2 uv) {
                return flixel_texture2D(source, uv);
            }
        " : "
            attribute float openfl_Alpha;
            attribute vec4 openfl_ColorMultiplier;
            attribute vec4 openfl_ColorOffset;
            attribute vec4 openfl_Position;
            attribute vec2 openfl_TextureCoord;

            varying float openfl_Alphav;
            varying vec4 openfl_ColorMultiplierv;
            varying vec4 openfl_ColorOffsetv;
            varying vec2 openfl_TextureCoordv;

            uniform mat4 openfl_Matrix;
            uniform bool openfl_HasColorTransform;
        ";

        var body = isFragment ?
            "gl_FragColor = flixel_texture2D(bitmap, openfl_TextureCoordv);" :
            "openfl_Alphav = openfl_Alpha;
            openfl_TextureCoordv = openfl_TextureCoord;
            if (openfl_HasColorTransform) {
                openfl_ColorMultiplierv = openfl_ColorMultiplier;
                openfl_ColorOffsetv = openfl_ColorOffset / 255.0;
            }
            gl_Position = openfl_Matrix * openfl_Position;";

        var result = src;
        if (result.indexOf("#pragma header") != -1) {
            result = result.replace("#pragma header", header);
        } else if (isFragment && result.indexOf("void main()") != -1 && result.indexOf("openfl_TextureCoordv") == -1) {
            result = header + "\n" + result;
        }

        if (result.indexOf("#pragma body") != -1) {
            result = result.replace("#pragma body", body);
        }

        return result;
    }
}