package soulscorch.backend;

import flixel.system.FlxAssets.FlxShader;

class RuntimeShader extends FlxShader {
    public function new(?fragCode:String, ?vertCode:String) {
        // If the modder provided custom fragment (pixel) code, inject it
        if (fragCode != null) {
            this.glFragmentSource = fragCode;
        }
        
        // If the modder provided custom vertex code, inject it
        if (vertCode != null) {
            this.glVertexSource = vertCode;
        }
        
        super();
    }
}