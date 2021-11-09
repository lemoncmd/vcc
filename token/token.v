module token

pub struct Token {
pub:
	kind Kind
	str  string
	line int
	pos  int
}

pub enum Kind {
	eof
	ident
	num
	str
	plus
	minus
	mul
	div
	mod
	xor
	aor
	aand
	lor
	land
	inc
	dec
	anot
	lnot
	lshift
	rshift
	lt
	gt
	le
	ge
	eq
	ne
	arrow
	comma
	colon
	dot
	semi
	question
	tridot
	assign
	pl_assign
	mn_assign
	ml_assign
	dv_assign
	md_assign
	an_assign
	or_assign
	xo_assign
	ls_assign
	rs_assign
	lcbr
	rcbr
	lpar
	rpar
	lsbr
	rsbr
	k_bool
	k_complex
	k_imaginary
	k_auto
	k_break
	k_case
	k_char
	k_const
	k_continue
	k_default
	k_do
	k_double
	k_else
	k_enum
	k_extern
	k_float
	k_for
	k_goto
	k_if
	k_inline
	k_int
	k_long
	k_register
	k_restrict
	k_return
	k_signed
	k_sizeof
	k_short
	k_static
	k_struct
	k_switch
	k_typedef
	k_union
	k_unsigned
	k_void
	k_volatile
	k_while
}

pub fn (k Kind) str() string {
	return match k {
		.eof {'EOF'}
		.ident {'identifier'}
		.num {'number'}
		.str {'string'}
		.plus {'`+`'}
		.minus {'`-`'}
		.mul {'`*`'}
		.div {'`/`'}
		.mod {'`%`'}
		.xor {'`^`'}
		.aor {'`|`'}
		.aand {'`&`'}
		.lor {'`||`'}
		.land {'`&&`'}
		.inc {'`++`'}
		.dec {'`--`'}
		.anot {'`~`'}
		.lnot {'`!`'}
		.lshift {'`<<`'}
		.rshift {'`>>`'}
		.lt {'`<`'}
		.gt {'`>`'}
		.le {'`<=`'}
		.ge {'`>=`'}
		.eq {'`==`'}
		.ne {'`!=`'}
		.arrow {'`->`'}
		.comma {'`,`'}
		.colon {'`:`'}
		.dot {'`.`'}
		.semi {'`;`'}
		.question {'`?`'}
		.tridot {'`...`'}
		.assign {'`=`'}
		.pl_assign {'`+=`'}
		.mn_assign {'`-=`'}
		.ml_assign {'`*=`'}
		.dv_assign {'`/=`'}
		.md_assign {'`%=`'}
		.an_assign {'`&=`'}
		.or_assign {'`|=`'}
		.xo_assign {'`^=`'}
		.ls_assign {'`<<=`'}
		.rs_assign {'`>>=`'}
		.lcbr {'`[`'}
		.rcbr {'`[`'}
		.lpar {'`[`'}
		.rpar {'`[`'}
		.lsbr {'`[`'}
		.rsbr {'`[`'}
		.k_bool {'`_Bool`'}
		.k_complex {'`_Complex`'}
		.k_imaginary {'`_Imaginary`'}
		.k_auto {'`auto`'}
		.k_break {'`break`'}
		.k_case {'`case`'}
		.k_char {'`char`'}
		.k_const {'`const`'}
		.k_continue {'`continue`'}
		.k_default {'`default`'}
		.k_do {'`do`'}
		.k_double {'`double`'}
		.k_else {'`else`'}
		.k_enum {'`enum`'}
		.k_extern {'`extern`'}
		.k_float {'`float`'}
		.k_for {'`for`'}
		.k_goto {'`goto`'}
		.k_if {'`if`'}
		.k_inline {'`inline`'}
		.k_int {'`int`'}
		.k_long {'`long`'}
		.k_register {'`register`'}
		.k_restrict {'`restrict`'}
		.k_return {'`return`'}
		.k_signed {'`signed`'}
		.k_sizeof {'`signed`'}
		.k_short {'`short`'}
		.k_static {'`static`'}
		.k_struct {'`struct`'}
		.k_switch {'`switch`'}
		.k_typedef {'`typedef`'}
		.k_union {'`union`'}
		.k_unsigned {'`unsigned`'}
		.k_void {'`void`'}
		.k_volatile {'`volatile`'}
		.k_while {'`while`'}
	}
}

[inline]
pub fn (k Kind) is_assign() bool {
	return int(k) >= int(Kind.assign) && int(k) <= int(Kind.rs_assign)
}

[inline]
pub fn (k Kind) is_keyword() bool {
	return int(k) >= int(Kind.k_bool)
}

pub const (
	reserves = [
		'_Bool',
		'_Complex',
		'_Imaginary',
		'auto',
		'break',
		'case',
		'char',
		'const',
		'continue',
		'default',
		'do',
		'double',
		'else',
		'enum',
		'extern',
		'float',
		'for',
		'goto',
		'if',
		'inline',
		'int',
		'long',
		'register',
		'restrict',
		'return',
		'signed',
		'sizeof',
		'short',
		'static',
		'struct',
		'switch',
		'typedef',
		'union',
		'unsigned',
		'void',
		'volatile',
		'while',
	]
)
