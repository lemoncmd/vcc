module ast

import token

pub struct FunctionDecl {
	typ Type
	body BlockStmt
}

pub type Stmt = BlockStmt
	| BreakStmt
	| CaseStmt
	| ContinueStmt
	| DoStmt
	| EmptyStmt
	| ForStmt
	| GotoStmt
	| IfStmt
	| LabelStmt
	| ReturnStmt
	| SwitchStmt

pub type Expr = BinaryExpr
	| CallExpr
	| CrementExpr
	| FloatLiteral
	| GvarLiteral
	| IntegerLiteral
	| LvarLiteral
	| SelectorExpr
	| StringLiteral
	| TernaryExpr
	| UnaryExpr

pub struct IfStmt {
pub:
	cond      Expr
	stmt      Stmt
	else_stmt Stmt
}

pub struct ForStmt {
pub:
	first ?Expr
	cond  Expr
	next  ?Expr
	stmt  Stmt
}

pub struct DoStmt {
pub:
	cond Expr
	stmt Stmt
}

pub struct SwitchStmt {
pub:
	cases []CaseStmt
	stmt  BlockStmt
}

pub struct LabelStmt {
pub:
	name string
	stmt Stmt
}

pub struct CaseStmt {
pub:
	expr Expr
	stmt Stmt
}

pub struct GotoStmt {
pub:
	name string
}

pub struct BreakStmt {
}

pub struct ContinueStmt {
}

pub struct ReturnStmt {
pub:
	expr Expr
}

pub struct BlockStmt {
pub:
	stmts []Stmt
}

pub struct EmptyStmt {
}

pub struct TernaryExpr {
pub:
	cond  Expr
	left  Expr
	right Expr
}

pub struct BinaryExpr {
pub:
	op    token.Kind
	left  Expr
	right Expr
}

pub struct UnaryExpr {
pub:
	op   token.Kind
	left Expr
}

pub struct SelectorExpr {
pub:
	left  Expr
	field string
}

pub struct CrementExpr {
pub:
	op       token.Kind
	is_front bool
	left     Expr
}

pub struct CallExpr {
pub:
	left Expr
	args []Expr
}

pub struct IntegerLiteral {
pub:
	val u64
}

pub struct FloatLiteral {
pub:
	val string
}

pub struct StringLiteral {
pub:
	val string
}

pub struct LvarLiteral {
pub:
	offset u64
}

pub struct GvarLiteral {
pub:
	name string
}

/*
sizof
  cast
*/
