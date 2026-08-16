package soulscorch.system;

import flixel.system.FlxAssets.FlxShader;
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

        if (fragSource != "") this.glFragmentSource = fragSource;
        if (vertSource != "") this.glVertexSource = vertSource;

        if (fragFile != "") shaderName = fragFile;

        super();
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
}