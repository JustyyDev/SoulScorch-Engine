package hscript;

import haxe.io.Input;
import hscript.Expr;

enum Token {
	TEof;
	TConst(c:Const);
	TId(s:String);
	TOp(op:String);
	TPOpen;
	TPClose;
	TBrOpen;
	TBrClose;
	TDot;
	TComma;
	TSemicolon;
	TBkOpen;
	TBkClose;
	TQuestion;
	TDoubleDot;
	TMeta(s:String);
}

class Parser {
	public var line:Int = 1;
	public var opPriority:Map<String, Int>;
	public var opRightAssoc:Map<String, Bool>;
	public var unops:Map<String, Bool>;

	public var allowTypes:Bool = true;
	public var allowJSON:Bool = true;
	public var allowMetadata:Bool = true;

	var input:Input;
	var char:Int;
	var ops:Array<Bool>;
	var idents:Array<Bool>;
	var tokens:Array<Token>;
	var origin:String;

	public function new() {
		var p = [
			["%"],
			["*", "/"],
			["+", "-"],
			["<<", ">>", ">>>"],
			["|", "&", "^"],
			["==", "!=", ">", "<", ">=", "<="],
			["..."],
			["&&"],
			["||"],
			["=", "+=", "-=", "*=", "/=", "%=", "<<=", ">>=", ">>>=", "|=", "&=", "^="],
			["->"]
		];
		opPriority = new Map();
		opRightAssoc = new Map();
		unops = new Map();

		for (i in 0...p.length)
			for (op in p[i]) {
				opPriority.set(op, i);
				if (i == 9) opRightAssoc.set(op, true);
			}

		for (op in ["!", "-", "++", "--", "~"])
			unops.set(op, true);

		ops = new Array();
		idents = new Array();
		tokens = new Array();

		var strOps = "+-*/%^&|!><=~.:";
		for (i in 0...strOps.length)
			ops[strOps.charCodeAt(i)] = true;

		for (i in 0...26) {
			idents["a".code + i] = true;
			idents["A".code + i] = true;
		}
		for (i in 0...10)
			idents["0".code + i] = true;
		idents["_".code] = true;
		idents["$".code] = true;
	}

	public function parseString(s:String, ?origin:String = "hscript"):Expr {
		this.origin = origin;
		line = 1;
		return parse(new haxe.io.StringInput(s), origin);
	}

	public function parse(input:Input, ?origin:String = "hscript"):Expr {
		this.origin = origin;
		this.input = input;
		char = -1;
		tokens = new Array();
		var a = new Array();
		while (true) {
			var tk = token();
			if (tk == TEof) break;
			push(tk);
			a.push(parseFullExpr());
		}
		return a.length == 1 ? a[0] : EBlock(a);
	}

	function parseFullExpr():Expr {
		var e = parseExpr();
		var tk = token();
		if (tk != TSemicolon && tk != TEof) push(tk);
		return e;
	}

	function parseExpr():Expr {
		var tk = token();
		switch (tk) {
			case TId(id):
				var e = parseStructure(id);
				if (e != null) return e;
				push(tk);
				return parseExprNext(parsePrimary());
			default:
				push(tk);
				return parseExprNext(parsePrimary());
		}
	}

	function parsePrimary():Expr {
		var tk = token();
		switch (tk) {
			case TId(id):
				return EIdent(id);
			case TConst(c):
				return EConst(c);
			case TPOpen:
				var e = parseExpr();
				ensure(TPClose);
				return EParent(e);
			case TBrOpen:
				tk = token();
				if (tk == TBrClose) return EObject([]);
				switch (tk) {
					case TId(_):
						var tk2 = token();
						push(tk2);
						push(tk);
						if (tk2 == TDoubleDot) return parseObject();
					default:
						push(tk);
				}
				var a = new Array();
				while (true) {
					a.push(parseFullExpr());
					tk = token();
					if (tk == TBrClose) break;
					push(tk);
				}
				return EBlock(a);
			case TBkOpen:
				var a = new Array();
				tk = token();
				while (tk != TBkClose) {
					push(tk);
					a.push(parseExpr());
					tk = token();
					if (tk == TComma) tk = token();
				}
				return EArrayDecl(a);
			case TOp(op):
				if (unops.exists(op)) return EUnop(op, true, parsePrimary());
				return unexpected(tk);
			case TMeta(id) if (allowMetadata):
				var args = parseMetaArgs();
				return EMeta(id, args, parseExpr());
			default:
				return unexpected(tk);
		}
	}

	function parseStructure(id:String):Expr {
		return switch (id) {
			case "import":
				var path = parseClassPath();
				var alias:String = null;
				var tk = token();
				switch (tk) {
					case TId("as"):
						switch (token()) {
							case TId(a): alias = a;
							default: unexpected(tk);
						}
					default:
						push(tk);
				}
				ensure(TSemicolon);
				EImport(path, alias);

			case "package":
				var path = parseClassPath();
				ensure(TSemicolon);
				EPackage(path);

			case "var", "public", "private", "static", "override":
				var isPublic = (id == "public");
				var isStatic = (id == "static");
				
				var next = token();
				while (true) {
					switch (next) {
						case TId("public"): isPublic = true; next = token();
						case TId("private"): isPublic = false; next = token();
						case TId("static"): isStatic = true; next = token();
						case TId("override"): next = token();
						case TId("var"): next = token(); break;
						case TId("function"): return parseFunction(isPublic, isStatic);
						default: break;
					}
				}
				
				var name = switch (next) {
					case TId(n): n;
					default: unexpected(next); "";
				};

				var t = parseType();
				var e:Expr = null;
				var tk = token();
				switch (tk) {
					case TOp("="): e = parseExpr();
					default: push(tk);
				}
				ensure(TSemicolon);
				EVar(name, t, e, isPublic, isStatic);

			case "function":
				parseFunction(false, false);

			case "if":
				ensure(TPOpen);
				var cond = parseExpr();
				ensure(TPClose);
				var e1 = parseExpr();
				var e2 = null;
				var tk = token();
				switch (tk) {
					case TId("else"):
						e2 = parseExpr();
					default:
						push(tk);
				}
				EIf(cond, e1, e2);

			case "while":
				ensure(TPOpen);
				var cond = parseExpr();
				ensure(TPClose);
				EWhile(cond, parseExpr());

			case "do":
				var e = parseExpr();
				var tkWhile = token();
				switch (tkWhile) {
					case TId("while"): // OK
					default: unexpected(tkWhile);
				}
				ensure(TPOpen);
				var cond = parseExpr();
				ensure(TPClose);
				EDoWhile(cond, e);

			case "for":
				ensure(TPOpen);
				var v = switch (token()) {
					case TId(v): v;
					default: unexpected(token()); "";
				};
				var tkIn = token();
				switch (tkIn) {
					case TId("in"): // OK
					default: unexpected(tkIn);
				}
				var it = parseExpr();
				ensure(TPClose);
				EFor(v, it, parseExpr());

			case "break": EBreak;
			case "continue": EContinue;
			case "return":
				var tk = token();
				push(tk);
				EReturn(tk == TSemicolon ? null : parseExpr());

			case "new":
				var cl = parseClassPath();
				var params = parseExprList(TPOpen, TPClose);
				ENew(cl, params);

			case "throw":
				EThrow(parseExpr());

			case "try":
				var e = parseExpr();
				var tkCatch = token();
				switch (tkCatch) {
					case TId("catch"): // OK
					default: unexpected(tkCatch);
				}
				ensure(TPOpen);
				var v = switch (token()) {
					case TId(v): v;
					default: unexpected(token()); "";
				};
				var t = parseType();
				ensure(TPClose);
				ETry(e, v, t, parseExpr());

			case "switch":
				ensure(TPOpen);
				var e = parseExpr();
				ensure(TPClose);
				var cases = [];
				var def = null;
				ensure(TBrOpen);
				while (true) {
					var tk = token();
					switch (tk) {
						case TId("case"):
							var values = [];
							while (true) {
								values.push(parseExpr());
								var tk2 = token();
								if (tk2 == TDoubleDot) break;
								if (tk2 != TComma) unexpected(tk2);
							}
							var exprs = [];
							while (true) {
								var tk2 = token();
								push(tk2);
								switch (tk2) {
									case TId("case") | TId("default") | TBrClose: break;
									default: exprs.push(parseFullExpr());
								}
							}
							cases.push({values: values, expr: exprs.length == 1 ? exprs[0] : EBlock(exprs)});
						case TId("default"):
							ensure(TDoubleDot);
							var exprs = [];
							while (true) {
								var tk2 = token();
								push(tk2);
								switch (tk2) {
									case TId("case") | TId("default") | TBrClose: break;
									default: exprs.push(parseFullExpr());
								}
							}
							def = exprs.length == 1 ? exprs[0] : EBlock(exprs);
						case TBrClose: break;
						default: unexpected(tk);
					}
					if (tk == TBrClose) break;
				}
				ESwitch(e, cases, def);

			default: null;
		}
	}

	function parseFunction(isPublic:Bool = false, isStatic:Bool = false):Expr {
		var name:String = null;
		var tk = token();
		switch (tk) {
			case TId(n): name = n;
			default: push(tk);
		}
		ensure(TPOpen);
		var args = new Array<Argument>();
		tk = token();
		while (tk != TPClose) {
			var argName = switch (tk) {
				case TId(n): n;
				default: unexpected(tk); "";
			};
			var t = parseType();
			var opt = false;
			var val:Expr = null;
			tk = token();
			switch (tk) {
				case TOp("="):
					opt = true;
					val = parseExpr();
					tk = token();
				default:
			}
			args.push({name: argName, t: t, opt: opt, value: val});
			if (tk == TComma) tk = token();
		}
		var ret = parseType();
		var body = parseExpr();
		return EFunction(args, body, name, ret);
	}

	function parseExprNext(e1:Expr):Expr {
		var tk = token();
		switch (tk) {
			case TOp(op):
				if (unops.exists(op)) {
					return parseExprNext(EUnop(op, false, e1));
				}
				var priority = opPriority.get(op);
				if (priority == null) {
					push(tk);
					return e1;
				}
				var e2 = parseExpr();
				return EBinop(op, e1, e2);
			case TDot:
				var field = switch (token()) {
					case TId(f): f;
					default: unexpected(token()); "";
				};
				return parseExprNext(EField(e1, field));
			case TPOpen:
				push(tk);
				var params = parseExprList(TPOpen, TPClose);
				return parseExprNext(ECall(e1, params));
			case TBkOpen:
				var index = parseExpr();
				ensure(TBkClose);
				return parseExprNext(EArray(e1, index));
			case TQuestion:
				var e2 = parseExpr();
				ensure(TDoubleDot);
				var e3 = parseExpr();
				return ETernary(e1, e2, e3);
			default:
				push(tk);
				return e1;
		}
	}

	function parseObject():Expr {
		var fl = new Array<{name:String, e:Expr}>();
		while (true) {
			var tk = token();
			var name = switch (tk) {
				case TId(n), TConst(CString(n)): n;
				case TBrClose: break;
				default: unexpected(tk); "";
			};
			ensure(TDoubleDot);
			fl.push({name: name, e: parseExpr()});
			tk = token();
			if (tk == TBrClose) break;
			if (tk != TComma) unexpected(tk);
		}
		return EObject(fl);
	}

	function parseExprList(open:Token, close:Token):Array<Expr> {
		ensure(open);
		var a = new Array();
		var tk = token();
		while (tk != close) {
			push(tk);
			a.push(parseExpr());
			tk = token();
			if (tk == TComma) tk = token();
		}
		return a;
	}

	function parseMetaArgs():Array<Expr> {
		var tk = token();
		if (tk != TPOpen) {
			push(tk);
			return null;
		}
		return parseExprList(TPOpen, TPClose);
	}

	function parseClassPath():String {
		var p = "";
		while (true) {
			var tk = token();
			switch (tk) {
				case TId(id): p += id;
				case TOp("*"): p += "*";
				default: unexpected(tk);
			}
			tk = token();
			if (tk == TDot) p += ".";
			else {
				push(tk);
				break;
			}
		}
		return p;
	}

	function parseType():CType {
		if (!allowTypes) return null;
		var tk = token();
		if (tk != TDoubleDot) {
			push(tk);
			return null;
		}
		var path = parseClassPath().split(".");
		return CTPath(path);
	}

	function token():Token {
		if (tokens.length > 0) return tokens.pop();
		while (true) {
			var c = readChar();
			switch (c) {
				case 0: return TEof;
				case " ".code, "\t".code, "\r".code:
				case "\n".code: line++;
				case ";".code: return TSemicolon;
				case ",".code: return TComma;
				case "(".code: return TPOpen;
				case ")".code: return TPClose;
				case "{".code: return TBrOpen;
				case "}".code: return TBrClose;
				case "[".code: return TBkOpen;
				case "]".code: return TBkClose;
				case "?".code: return TQuestion;
				case ":".code: return TDoubleDot;
				case "@".code:
					if (allowMetadata) {
						var id = switch (token()) {
							case TId(i): i;
							default: "";
						};
						return TMeta(id);
					}
				case "/".code:
					var c2 = readChar();
					if (c2 == "/".code) {
						while (true) {
							var ch = readChar();
							if (ch == 0 || ch == "\n".code) {
								if (ch == "\n".code) line++;
								break;
							}
						}
					} else if (c2 == "*".code) {
						while (true) {
							var ch = readChar();
							if (ch == 0) error(EUnterminatedComment);
							if (ch == "\n".code) line++;
							if (ch == "*".code) {
								var ch2 = readChar();
								if (ch2 == "/".code) break;
								if (ch2 != 0) char = ch2;
							}
						}
					} else {
						char = c2;
						return parseOp("/");
					}
				case '"'.code, "'".code:
					return TConst(CString(readString(c)));
				default:
					if (ops[c]) return parseOp(String.fromCharCode(c));
					if (idents[c]) return parseIdent(String.fromCharCode(c));
					if (c >= "0".code && c <= "9".code) return parseNumber(String.fromCharCode(c));
					error(EInvalidChar(c));
			}
		}
	}

	function parseOp(op:String):Token {
		while (true) {
			var c = readChar();
			if (!ops[c] || c == "/".code) {
				char = c;
				break;
			}
			op += String.fromCharCode(c);
		}
		if (op == ".") return TDot;
		return TOp(op);
	}

	function parseIdent(id:String):Token {
		while (true) {
			var c = readChar();
			if (!idents[c]) {
				char = c;
				break;
			}
			id += String.fromCharCode(c);
		}
		return switch (id) {
			case "null": TId("null");
			case "true": TId("true");
			case "false": TId("false");
			default: TId(id);
		}
	}

	function parseNumber(num:String):Token {
		var isFloat = false;
		while (true) {
			var c = readChar();
			if (c == ".".code) {
				isFloat = true;
				num += ".";
			} else if (c >= "0".code && c <= "9".code) {
				num += String.fromCharCode(c);
			} else {
				char = c;
				break;
			}
		}
		return TConst(isFloat ? CFloat(Std.parseFloat(num)) : CInt(Std.parseInt(num)));
	}

	function readString(quote:Int):String {
		var str = "";
		while (true) {
			var c = readChar();
			if (c == 0) error(EUnterminatedString);
			if (c == quote) break;
			if (c == "\\".code) {
				var c2 = readChar();
				switch (c2) {
					case "n".code: str += "\n";
					case "t".code: str += "\t";
					case "r".code: str += "\r";
					case "\\".code: str += "\\";
					case '"'.code: str += '"';
					case "'".code: str += "'";
					default: str += "\\" + String.fromCharCode(c2);
				}
			} else {
				str += String.fromCharCode(c);
			}
		}
		return str;
	}

	inline function readChar():Int {
		if (char != -1) {
			var c = char;
			char = -1;
			return c;
		}
		return try input.readByte() catch (e:Dynamic) 0;
	}

	inline function push(t:Token):Void {
		tokens.push(t);
	}

	function ensure(t:Token):Void {
		var tk = token();
		if (Type.enumIndex(tk) != Type.enumIndex(t)) unexpected(tk);
	}

	function unexpected(tk:Token):Dynamic {
		error(EUnexpected(Std.string(tk)));
		return null;
	}

	function error(err:ErrorDef):Void {
		throw {e: err, line: line, origin: origin, pmin: 0, pmax: 0};
	}
}