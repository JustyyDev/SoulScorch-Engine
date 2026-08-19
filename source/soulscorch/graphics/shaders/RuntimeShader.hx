package soulscorch.graphics.shaders;

import flixel.FlxG;
import flixel.system.FlxAssets.FlxShader;
import openfl.display.BitmapData;
import openfl.filters.ShaderFilter;
import soulscorch.backend.assets.AssetResolver;
import soulscorch.graphics.shaders.SoulShader;

using StringTools;

class RuntimeShader extends FlxShader {
    public var shaderName:String;
    public var filter(get, null):ShaderFilter;
    private var _cachedFilter:ShaderFilter;

    public inline function get_filter():ShaderFilter {
        if (_cachedFilter == null) {
            _cachedFilter = new ShaderFilter(this);
        }
        return _cachedFilter;
    }

    public function new(?fragSource:String, ?vertSource:String, name:String = "RuntimeShader") {
        this.shaderName = name;

        var fSource:String = (fragSource != null && fragSource.trim().length > 0) ? fragSource : SoulShader.DEFAULT_FRAGMENT;
        var vSource:String = (vertSource != null && vertSource.trim().length > 0) ? vertSource : SoulShader.DEFAULT_VERTEX;

        this.glFragmentSource = SoulShader.expandPragmas(fSource, true);
        this.glVertexSource = SoulShader.expandPragmas(vSource, false);

        super();

        setFloatArray("iResolution", [FlxG.width, FlxG.height]);
        setFloat("iTime", 0.0);
    }

    public static function fromFile(fragPath:String, ?vertPath:String):RuntimeShader {
        var fragCode = AssetResolver.getText(fragPath);
        var vertCode = (vertPath != null && vertPath.length > 0) ? AssetResolver.getText(vertPath) : null;

        return new RuntimeShader(fragCode, vertCode, fragPath);
    }

    public function update(elapsed:Float):Void {
        var cur = getFloat("iTime");
        setFloat("iTime", cur + elapsed);
        setFloat("u_time", cur + elapsed);
    }

    public function setFloat(name:String, value:Float):Void {
        if (data != null && Reflect.hasField(data, name)) {
            var prop:Dynamic = Reflect.field(data, name);
            if (prop != null) prop.value = [value];
        }
    }

    public function getFloat(name:String):Float {
        if (data != null && Reflect.hasField(data, name)) {
            var prop:Dynamic = Reflect.field(data, name);
            if (prop != null && prop.value != null && prop.value.length > 0) {
                return prop.value[0];
            }
        }
        return 0.0;
    }

    public function setFloatArray(name:String, values:Array<Float>):Void {
        if (data != null && Reflect.hasField(data, name)) {
            var prop:Dynamic = Reflect.field(data, name);
            if (prop != null) prop.value = values;
        }
    }

    public function setInt(name:String, value:Int):Void {
        if (data != null && Reflect.hasField(data, name)) {
            var prop:Dynamic = Reflect.field(data, name);
            if (prop != null) prop.value = [value];
        }
    }

    public function setBool(name:String, value:Bool):Void {
        if (data != null && Reflect.hasField(data, name)) {
            var prop:Dynamic = Reflect.field(data, name);
            if (prop != null) prop.value = [value];
        }
    }

    public function setSampler2D(name:String, bitmap:BitmapData):Void {
        if (data != null && Reflect.hasField(data, name)) {
            var prop:Dynamic = Reflect.field(data, name);
            if (prop != null) prop.input = bitmap;
        }
    }
}