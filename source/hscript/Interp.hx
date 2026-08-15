package hscript;

import haxe.PosInfos;
import haxe.Constraints.IMap;
import hscript.Expr;

class Interp {
	public var variables:Map<String, Dynamic>;
	public var locals:Map<String, {r:Dynamic}>;
	public var binops:Map<String, Expr->Expr->Dynamic>;
	public var importedPackages:Array<String>;
	public var scriptPath:String = "";

	var depth:Int = 0;
	var inTry:Bool = false;
	var declared:Array<{n:String, old:{r:Dynamic}}>;

	public function new() {
		variables = new Map<String, Dynamic>();
		locals = new Map<String, {r:Dynamic}>();
		declared = new Array();
		binops = new Map();
		importedPackages = [
			"",
			"flixel.",
			"flixel.math.",
			"flixel.text.",
			"flixel.util.",
			"flixel.tweens.",
			"flixel.group.",
			"soulscorch.core.",
			"soulscorch.gameplay.",
			"soulscorch.assets.",
			"soulscorch.ui."
		];

		initDefaultScope();
		initBinops();
	}

	function initDefaultScope():Void {
		variables.set("null", null);
		variables.set("true", true);
		variables.set("false", false);
		variables.set("trace", Reflect.makeVarArgs(function(args) {
			var pos:PosInfos = {fileName: scriptPath != "" ? scriptPath : "hscript", lineNumber: 0, className: "Script", methodName: "trace"};
			haxe.Log.trace(args.length == 1 ? Std.string(args[0]) : args.map(Std.string).join(", "), pos);
		}));
		variables.set("Math", Math);
		variables.set("Std", Std);
		variables.set("StringTools", StringTools);
		variables.set("Reflect", Reflect);
		variables.set("Type", Type);
		variables.set("IntIterator", IntIterator);
		#if sys
		variables.set("Sys", Sys);
		#end
	}

	public function execute(expr:Expr):Dynamic {
		depth = 0;
		locals = new Map();
		declared = new Array();
		return exprReturn(expr);
	}

	function exprReturn(e:Expr):Dynamic {
		if (e == null) return null;
		switch (e) {
			case EImport(target, alias):
				handleImport(target, alias);
				return null;

			case EPackage(_):
				return null;

			case EConst(c):
				return switch (c) {
					case CInt(v): v;
					case CFloat(f): f;
					case CString(s): s;
				};

			case EIdent(id):
				return resolve(id);

			case EVar(n, _, e, _, _):
				var val:Dynamic = e == null ? null : expr(e);
				declared.push({n: n, old: locals.get(n)});
				locals.set(n, {r: val});
				return val;

			case EParent(e):
				return expr(e);

			case EBlock(exprs):
				var oldPos = declared.length;
				var v:Dynamic = null;
				for (e in exprs)
					v = expr(e);
				restoreLocals(oldPos);
				return v;

			case EField(e, f):
				return get(expr(e), f);

			case EBinop(op, e1, e2):
				var f = binops.get(op);
				if (f == null) error(EInvalidOp(op));
				return f(e1, e2);

			case EUnop(op, prefix, e):
				return handleUnop(op, prefix, e);

			case ECall(e, params):
				var args = [for (p in params) expr(p)];
				return handleCall(e, args);

			case EIf(cond, e1, e2):
				return if (expr(cond) == true) expr(e1) else (e2 == null ? null : expr(e2));

			case EWhile(cond, e):
				while (expr(cond) == true) {
					try {
						expr(e);
					} catch (err:Dynamic) {
						if (err == "_hx_break") break;
						if (err == "_hx_continue") continue;
						throw err;
					}
				}
				return null;

			case EDoWhile(cond, e):
				do {
					try {
						expr(e);
					} catch (err:Dynamic) {
						if (err == "_hx_break") break;
						if (err == "_hx_continue") continue;
						throw err;
					}
				} while (expr(cond) == true);
				return null;

			case EFor(v, it, e):
				var iterator:Dynamic = expr(it);
				if (iterator == null) error(EInvalidIterator(v));

				var itObj:Iterator<Dynamic> = null;
				if (Std.isOfType(iterator, Array)) {
					itObj = (iterator : Array<Dynamic>).iterator();
				} else if (Std.isOfType(iterator, IMap)) {
					itObj = (cast iterator : IMap<Dynamic, Dynamic>).iterator();
				} else if (Reflect.isObject(iterator) && Reflect.hasField(iterator, "hasNext") && Reflect.hasField(iterator, "next")) {
					itObj = cast iterator;
				} else {
					try {
						itObj = iterator.iterator();
					} catch (err:Dynamic) {
						error(EInvalidIterator(v));
					}
				}

				var oldPos = declared.length;
				while (itObj.hasNext()) {
					var itVal = itObj.next();
					declared.push({n: v, old: locals.get(v)});
					locals.set(v, {r: itVal});
					try {
						expr(e);
					} catch (err:Dynamic) {
						if (err == "_hx_break") break;
						if (err == "_hx_continue") continue;
						restoreLocals(oldPos);
						throw err;
					}
				}
				restoreLocals(oldPos);
				return null;

			case EBreak:
				throw "_hx_break";

			case EContinue:
				throw "_hx_continue";

			case EReturn(e):
				throw {r: e == null ? null : expr(e)};

			case EThrow(e):
				throw expr(e);

			case ETry(e, v, _, ecatch):
				var oldPos = declared.length;
				try {
					return expr(e);
				} catch (err:Dynamic) {
					if (err == "_hx_break" || err == "_hx_continue") throw err;
					if (Reflect.isObject(err) && Reflect.hasField(err, "r")) throw err;
					declared.push({n: v, old: locals.get(v)});
					locals.set(v, {r: err});
					var res = expr(ecatch);
					restoreLocals(oldPos);
					return res;
				}

			case ESwitch(e, cases, defaultExpr):
				var val:Dynamic = expr(e);
				var matched = false;
				for (c in cases) {
					for (v in c.values) {
						if (expr(v) == val) {
							matched = true;
							return expr(c.expr);
						}
					}
				}
				if (!matched && defaultExpr != null) {
					return expr(defaultExpr);
				}
				return null;

			case EFunction(params, fexpr, name, _):
				var capturedLocals = duplicateLocals(locals);
				var fn = function(args:Array<Dynamic>) {
					var oldLocals = locals;
					var oldDeclared = declared;
					locals = duplicateLocals(capturedLocals);
					declared = new Array();

					for (i in 0...params.length) {
						var param = params[i];
						var val = (args != null && i < args.length) ? args[i] : (param.value == null ? null : expr(param.value));
						locals.set(param.name, {r: val});
					}

					var ret:Dynamic = null;
					try {
						ret = expr(fexpr);
					} catch (err:Dynamic) {
						if (Reflect.isObject(err) && Reflect.hasField(err, "r")) {
							ret = err.r;
						} else {
							locals = oldLocals;
							declared = oldDeclared;
							throw err;
						}
					}
					locals = oldLocals;
					declared = oldDeclared;
					return ret;
				};

				var dynamicFn = Reflect.makeVarArgs(fn);
				if (name != null) {
					if (depth == 0) variables.set(name, dynamicFn);
					else locals.set(name, {r: dynamicFn});
				}
				return dynamicFn;

			case EArray(e, index):
				var arr:Dynamic = expr(e);
				var idx:Dynamic = expr(index);
				if (Std.isOfType(arr, Array)) return (arr : Array<Dynamic>)[idx];
				if (Std.isOfType(arr, IMap)) return (cast arr : IMap<Dynamic, Dynamic>).get(idx);
				return arr[idx];

			case EArrayDecl(exprs):
				return [for (e in exprs) expr(e)];

			case ENew(cl, params):
				var targetClass = resolveClassPath(cl);
				if (targetClass == null) error(ECustom('Class not found: $cl'));
				var args = [for (p in params) expr(p)];
				return Type.createInstance(targetClass, args);

			case ETernary(cond, e1, e2):
				return if (expr(cond) == true) expr(e1) else expr(e2);

			case EObject(fl):
				var obj = {};
				for (f in fl)
					Reflect.setField(obj, f.name, expr(f.e));
				return obj;

			default:
				error(ECustom("Unhandled expression: " + e));
				return null;
		}
	}

	inline function expr(e:Expr):Dynamic {
		return exprReturn(e);
	}

	function handleImport(target:String, alias:String):Void {
		if (StringTools.endsWith(target, ".*")) {
			var pkg = target.substr(0, target.length - 1);
			if (!importedPackages.contains(pkg)) importedPackages.unshift(pkg);
		} else {
			var cls = Type.resolveClass(target);
			var enm = Type.resolveEnum(target);
			var resolvedName = alias != null ? alias : target.split(".").pop();
			if (cls != null) variables.set(resolvedName, cls);
			else if (enm != null) variables.set(resolvedName, enm);
			else error(ECustom('Cannot resolve import: $target'));
		}
	}

	public function resolveClassPath(name:String):Class<Dynamic> {
		var directCls = Type.resolveClass(name);
		if (directCls != null) return directCls;

		for (pkg in importedPackages) {
			var cls = Type.resolveClass(pkg + name);
			if (cls != null) return cls;
		}
		return null;
	}

	function resolve(id:String):Dynamic {
		var l = locals.get(id);
		if (l != null) return l.r;
		if (variables.exists(id)) return variables.get(id);

		var cls = resolveClassPath(id);
		if (cls != null) return cls;

		var enm = Type.resolveEnum(id);
		if (enm != null) return enm;

		error(EUnknownVariable(id));
		return null;
	}

	function get(o:Dynamic, f:String):Dynamic {
		if (o == null) error(EInvalidAccess(f));
		return Reflect.getProperty(o, f);
	}

	function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
		if (o == null) error(EInvalidAccess(f));
		Reflect.setProperty(o, f, v);
		return v;
	}

	function handleCall(e:Expr, args:Array<Dynamic>):Dynamic {
		switch (e) {
			case EField(objExpr, fieldName):
				var targetObj = expr(objExpr);
				if (targetObj == null) error(EInvalidAccess(fieldName));
				var fn = Reflect.getProperty(targetObj, fieldName);
				if (fn == null) error(ECustom('Method $fieldName does not exist on target'));
				return Reflect.callMethod(targetObj, fn, args);

			default:
				var fn = expr(e);
				if (!Reflect.isFunction(fn)) error(ECustom('Expression is not a callable function'));
				return Reflect.callMethod(null, fn, args);
		}
	}

	function handleUnop(op:String, prefix:Bool, e:Expr):Dynamic {
		switch (e) {
			case EIdent(id):
				var l = locals.get(id);
				var val:Dynamic = l != null ? l.r : variables.get(id);
				var res:Dynamic = null;
				switch (op) {
					case "!":
						res = (val != true);
					case "-":
						res = -val;
					case "~":
						res = ~val;
					case "++":
						var newVal = val + 1;
						if (l != null) l.r = newVal; else variables.set(id, newVal);
						return prefix ? newVal : val;
					case "--":
						var newVal = val - 1;
						if (l != null) l.r = newVal; else variables.set(id, newVal);
						return prefix ? newVal : val;
					default:
						error(EInvalidOp(op));
				}
				return res;
			default:
				var val:Dynamic = expr(e);
				var res:Dynamic = null;
				switch (op) {
					case "!":
						res = (val != true);
					case "-":
						res = -val;
					case "~":
						res = ~val;
					default:
						error(EInvalidOp(op));
				}
				return res;
		}
	}

	function assignOp(op:String, fop:Dynamic->Dynamic->Dynamic):Void {
		binops.set(op, function(e1, e2) {
			var v2 = expr(e2);
			switch (e1) {
				case EIdent(id):
					var l = locals.get(id);
					var v1 = l != null ? l.r : variables.get(id);
					var v = fop(v1, v2);
					if (l != null) l.r = v; else variables.set(id, v);
					return v;
				case EField(e, f):
					var obj = expr(e);
					var v1 = get(obj, f);
					var v = fop(v1, v2);
					set(obj, f, v);
					return v;
				case EArray(e, index):
					var arr:Dynamic = expr(e);
					var idx:Dynamic = expr(index);
					if (Std.isOfType(arr, Array)) {
						var v = fop((arr : Array<Dynamic>)[idx], v2);
						(arr : Array<Dynamic>)[idx] = v;
						return v;
					} else if (Std.isOfType(arr, IMap)) {
						var map:IMap<Dynamic, Dynamic> = cast arr;
						var v = fop(map.get(idx), v2);
						map.set(idx, v);
						return v;
					} else {
						var v = fop(arr[idx], v2);
						arr[idx] = v;
						return v;
					}
				default:
					error(EInvalidOp(op));
					return null;
			}
		});
	}

	function initBinops():Void {
		binops.set("+", function(e1, e2) return expr(e1) + expr(e2));
		binops.set("-", function(e1, e2) return expr(e1) - expr(e2));
		binops.set("*", function(e1, e2) return expr(e1) * expr(e2));
		binops.set("/", function(e1, e2) return expr(e1) / expr(e2));
		binops.set("%", function(e1, e2) return expr(e1) % expr(e2));
		binops.set("&", function(e1, e2) return expr(e1) & expr(e2));
		binops.set("|", function(e1, e2) return expr(e1) | expr(e2));
		binops.set("^", function(e1, e2) return expr(e1) ^ expr(e2));
		binops.set("<<", function(e1, e2) return expr(e1) << expr(e2));
		binops.set(">>", function(e1, e2) return expr(e1) >> expr(e2));
		binops.set(">>>", function(e1, e2) return expr(e1) >>> expr(e2));
		binops.set("==", function(e1, e2) return expr(e1) == expr(e2));
		binops.set("!=", function(e1, e2) return expr(e1) != expr(e2));
		binops.set(">=", function(e1, e2) return expr(e1) >= expr(e2));
		binops.set("<=", function(e1, e2) return expr(e1) <= expr(e2));
		binops.set(">", function(e1, e2) return expr(e1) > expr(e2));
		binops.set("<", function(e1, e2) return expr(e1) < expr(e2));
		binops.set("&&", function(e1, e2) return expr(e1) == true && expr(e2) == true);
		binops.set("||", function(e1, e2) return expr(e1) == true || expr(e2) == true);
		binops.set("...", function(e1, e2) return new IntIterator(expr(e1), expr(e2)));

		binops.set("=", function(e1, e2) {
			var v = expr(e2);
			switch (e1) {
				case EIdent(id):
					var l = locals.get(id);
					if (l != null) l.r = v;
					else variables.set(id, v);
				case EField(e, f):
					set(expr(e), f, v);
				case EArray(e, index):
					var arr:Dynamic = expr(e);
					var idx:Dynamic = expr(index);
					if (Std.isOfType(arr, Array)) (arr : Array<Dynamic>)[idx] = v;
					else if (Std.isOfType(arr, IMap)) (cast arr : IMap<Dynamic, Dynamic>).set(idx, v);
					else arr[idx] = v;
				default: error(EInvalidOp("="));
			}
			return v;
		});

		assignOp("+=", function(v1, v2) return v1 + v2);
		assignOp("-=", function(v1, v2) return v1 - v2);
		assignOp("*=", function(v1, v2) return v1 * v2);
		assignOp("/=", function(v1, v2) return v1 / v2);
		assignOp("%=", function(v1, v2) return v1 % v2);
		assignOp("&=", function(v1, v2) return v1 & v2);
		assignOp("|=", function(v1, v2) return v1 | v2);
		assignOp("^=", function(v1, v2) return v1 ^ v2);
		assignOp("<<=", function(v1, v2) return v1 << v2);
		assignOp(">>=", function(v1, v2) return v1 >> v2);
		assignOp(">>>=", function(v1, v2) return v1 >>> v2);
	}

	function restoreLocals(oldPos:Int):Void {
		while (declared.length > oldPos) {
			var d = declared.pop();
			if (d.old == null) locals.remove(d.n);
			else locals.set(d.n, d.old);
		}
	}

	function duplicateLocals(h:Map<String, {r:Dynamic}>):Map<String, {r:Dynamic}> {
		var dup = new Map<String, {r:Dynamic}>();
		for (k in h.keys())
			dup.set(k, {r: h.get(k).r});
		return dup;
	}

	function error(e:ErrorDef):Void {
		#if sys
		Sys.println('[HSCRIPT ERROR] $e in $scriptPath');
		#end
		throw e;
	}
}