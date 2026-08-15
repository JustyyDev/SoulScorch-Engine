package hscript;

enum Const {
	CString(v:String);
	CInt(v:Int);
	CFloat(v:Float);
}

enum ErrorDef {
	EInvalidChar(c:Int);
	EUnexpected(s:String);
	EUnterminatedString;
	EUnterminatedComment;
	EInvalidPreprocessor(msg:String);
	EUnknownVariable(v:String);
	EInvalidIterator(v:String);
	EInvalidOp(op:String);
	EInvalidAccess(f:String);
	ECustom(msg:String);
}

typedef Error = {
	var e:ErrorDef;
	var pmin:Int;
	var pmax:Int;
	var origin:String;
	var line:Int;
}

enum Expr {
	EConst(c:Const);
	EIdent(v:String);
	EVar(n:String, ?t:CType, ?e:Expr, ?isPublic:Bool, ?isStatic:Bool);
	EParent(e:Expr);
	EBlock(e:Array<Expr>);
	EField(e:Expr, f:String);
	EBinop(op:String, e1:Expr, e2:Expr);
	EUnop(op:String, prefix:Bool, e:Expr);
	ECall(e:Expr, params:Array<Expr>);
	EIf(cond:Expr, e1:Expr, ?e2:Expr);
	EWhile(cond:Expr, e:Expr);
	EFor(v:String, it:Expr, e:Expr);
	EBreak;
	EContinue;
	EFunction(args:Array<Argument>, e:Expr, ?name:String, ?ret:CType);
	EReturn(?e:Expr);
	EArray(e:Expr, index:Expr);
	EArrayDecl(e:Array<Expr>);
	ENew(cl:String, params:Array<Expr>);
	EThrow(e:Expr);
	ETry(e:Expr, v:String, t:Null<CType>, ecatch:Expr);
	EObject(fl:Array<{name:String, e:Expr}>);
	ETernary(cond:Expr, e1:Expr, e2:Expr);
	ESwitch(e:Expr, cases:Array<{values:Array<Expr>, expr:Expr}>, ?defaultExpr:Expr);
	EDoWhile(cond:Expr, e:Expr);
	EMeta(name:String, args:Array<Expr>, e:Expr);
	ECheckType(e:Expr, t:CType);
	// SOULSCORCH EXTENSIONS
	EImport(target:String, ?alias:String);
	EPackage(pkg:String);
}

typedef Argument = {name:String, ?t:CType, ?opt:Bool, ?value:Expr};

enum CType {
	CTPath(path:Array<String>, ?params:Array<CType>);
	CTFun(args:Array<CType>, ret:CType);
	CTAnon(fields:Array<{name:String, t:CType, ?meta:Array<Metadata>}>);
	CTParent(t:CType);
}

typedef Metadata = {name:String, ?args:Array<Expr>};