package haxe;

/**
	Log primarily used for printing `trace()` output.
**/
class Log {
	/**
		Format the output of `trace` before printing it.
	**/
	public static function formatOutput(v:Dynamic, infos:PosInfos):String {
		var str = Std.string(v);
		if (infos == null)
			return str;
		var pstr = infos.fileName + ":" + infos.lineNumber;
		if (infos.customParams != null) {
			for (v in infos.customParams)
				str += ", " + Std.string(v);
		}
		return pstr + ": " + str;
	}

	/**
		Outputs `v` to the standard console and the SoulScorch Engine UI.
	**/
	public static dynamic function trace(v:Dynamic, ?infos:PosInfos):Void {
		var str = formatOutput(v, infos);

		#if js
		if (js.Browser.supported) {
			js.Browser.console.log(str);
		} else {
			untyped console.log(str);
		}
		#elseif lua
		untyped __define_feature__("use._hx_print", _hx_print(str + "\n"));
		#elseif sys
		Sys.println(str);
		#end

		// [SOULSCORCH EXTENSION] Push traces directly to the in-game developer console!
		try {
			var runtimeClass = Type.resolveClass("soulscorch.core.Runtime");
			if (runtimeClass != null) {
				var engine:Dynamic = Reflect.getProperty(runtimeClass, "engine");
				if (engine != null) {
					// Dynamically call the console push if it exists, preventing crashes if the UI isn't ready
					if (Reflect.hasField(engine, "pushConsoleLog")) {
						var pushMethod = Reflect.field(engine, "pushConsoleLog");
						Reflect.callMethod(engine, pushMethod, [str]);
					}
				}
			}
		} catch(e:Dynamic) {
			// Silently fail if the engine hasn't booted yet, ensuring early trace() calls still work
		}
	}
}