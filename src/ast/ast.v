module ast

import token

pub struct FunctionDecl {
pub:
	typ  Type
	body BlockStmt
}

pub type Stmt = BlockStmt
	| BreakStmt
	| CaseStmt
	| ContinueStmt
	| DeclStmt
	| DefaultStmt
	| DoStmt
	| EmptyStmt
	| ExprStmt
	| ForStmt
	| GotoStmt
	| IfStmt
	| LabelStmt
	| ReturnStmt
	| SwitchStmt
	| WhileStmt

pub type Expr = BinaryExpr
	| CallExpr
	| CastExpr
	| CrementExpr
	| FloatLiteral
	| GvarLiteral
	| IntegerLiteral
	| LvarLiteral
	| SelectorExpr
	| SizeofExpr
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
	first Stmt
	cond  Expr
	next  Expr
	stmt  Stmt
	table ScopeTable
}

pub struct WhileStmt {
pub:
	cond Expr
	stmt Stmt
}

pub struct DoStmt {
pub:
	cond Expr
	stmt Stmt
}

pub struct SwitchStmt {
pub:
	cond Expr
pub mut:
	cases []CaseOrDefault
	stmt  Stmt
}

pub struct LabelStmt {
pub:
	name string
	stmt Stmt
}

pub type CaseOrDefault = CaseStmt | DefaultStmt

pub struct DefaultStmt {
pub:
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
	table ScopeTable
}

pub struct EmptyStmt {
}

pub struct ExprStmt {
pub:
	expr Expr
}

pub struct DeclStmt {
pub:
	decls []Decl
}

pub struct Decl {
pub:
	typ  Type
	name string
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
	name string
}

pub struct GvarLiteral {
pub:
	name string
}

pub type SizeofExpr = Expr | Type

pub struct CastExpr {
	typ  Type
	left Expr
}

pub type Init = Expr | []Init