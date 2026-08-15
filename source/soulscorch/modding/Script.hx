package soulscorch.modding;

import flixel.FlxG;
import hscript.Interp;
import hscript.Parser;
import hscript.Expr;
import soulscorch.assets.AssetResolver;
import soulscorch.gameplay.Conductor;

class Script {
	public var interp:Interp;
	public var parser:Parser;
	public var ast:Expr;
	public var active:Bool = false;
	public var scriptPath:String;

	public function new(path:String) {
		this.scriptPath = path;
		interp = new Interp();
		parser = new Parser();
		
		parser.allowTypes = true;
		parser.allowJSON = true;
		parser.allowMetadata = true;
		interp.scriptPath = path;

		load();
	}

	public function load():Void {
		var fullPath = ModLoader.getPath(scriptPath);
		if (!AssetResolver.exists(fullPath)) {
			active = false;
			return;
		}

		try {
			var code = AssetResolver.getText(fullPath);
			ast = parser.parseString(code);
			presetVariables();
			interp.execute(ast);
			active = true;
		} catch (e:Dynamic) {
			Sys.println('[SCRIPT ERROR] Failed to load $scriptPath: $e');
			active = false;
		}
	}

	public function presetVariables():Void {
		set("FlxG", FlxG);
		set("Conductor", Conductor);
		set("script", this);
		set("scriptPath", scriptPath);
	}

	public function set(name:String, value:Dynamic):Void {
		interp.variables.set(name, value);
	}

	public function get(name:String):Dynamic {
		return interp.variables.get(name);
	}

	public function call(func:String, args:Array<Dynamic> = null):Dynamic {
		if (!active) return null;
		if (args == null) args = [];

		var fn = get(func);
		if (fn != null && Reflect.isFunction(fn)) {
			try {
				return Reflect.callMethod(null, fn, args);
			} catch (e:Dynamic) {
				Sys.println('[SCRIPT EXECUTION ERROR] in $scriptPath ($func): $e');
			}
		}
		return null;
	}

	public function destroy():Void {
		active = false;
		interp = null;
		parser = null;
		ast = null;
	}
}