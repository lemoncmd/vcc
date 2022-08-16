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
	k_alignas
	k_atomic
	k_bool
	k_complex
	k_generic
	k_imaginary
	k_noreturn
	k_static_assert
	k_thread_local
	k_alignof
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
	k_short
	k_signed
	k_sizeof
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
		.eof { 'EOF' }
		.ident { 'identifier' }
		.num { 'number' }
		.str { 'string' }
		.plus { '`+`' }
		.minus { '`-`' }
		.mul { '`*`' }
		.div { '`/`' }
		.mod { '`%`' }
		.xor { '`^`' }
		.aor { '`|`' }
		.aand { '`&`' }
		.lor { '`||`' }
		.land { '`&&`' }
		.inc { '`++`' }
		.dec { '`--`' }
		.anot { '`~`' }
		.lnot { '`!`' }
		.lshift { '`<<`' }
		.rshift { '`>>`' }
		.lt { '`<`' }
		.gt { '`>`' }
		.le { '`<=`' }
		.ge { '`>=`' }
		.eq { '`==`' }
		.ne { '`!=`' }
		.arrow { '`->`' }
		.comma { '`,`' }
		.colon { '`:`' }
		.dot { '`.`' }
		.semi { '`;`' }
		.question { '`?`' }
		.tridot { '`...`' }
		.assign { '`=`' }
		.pl_assign { '`+=`' }
		.mn_assign { '`-=`' }
		.ml_assign { '`*=`' }
		.dv_assign { '`/=`' }
		.md_assign { '`%=`' }
		.an_assign { '`&=`' }
		.or_assign { '`|=`' }
		.xo_assign { '`^=`' }
		.ls_assign { '`<<=`' }
		.rs_assign { '`>>=`' }
		.lcbr { '`[`' }
		.rcbr { '`]`' }
		.lpar { '`(`' }
		.rpar { '`)`' }
		.lsbr { '`{`' }
		.rsbr { '`}`' }
		.k_alignas { '`_Alignas`' }
		.k_atomic { '`_Atomic`' }
		.k_bool { '`_Bool`' }
		.k_complex { '`_Complex`' }
		.k_generic { '`_Generic`' }
		.k_imaginary { '`_Imaginary`' }
		.k_noreturn { '`_Noreturn`' }
		.k_static_assert { '`_Static_assert`' }
		.k_thread_local { '`_Thread_local`' }
		.k_alignof { '`alignof`' }
		.k_auto { '`auto`' }
		.k_break { '`break`' }
		.k_case { '`case`' }
		.k_char { '`char`' }
		.k_const { '`const`' }
		.k_continue { '`continue`' }
		.k_default { '`default`' }
		.k_do { '`do`' }
		.k_double { '`double`' }
		.k_else { '`else`' }
		.k_enum { '`enum`' }
		.k_extern { '`extern`' }
		.k_float { '`float`' }
		.k_for { '`for`' }
		.k_goto { '`goto`' }
		.k_if { '`if`' }
		.k_inline { '`inline`' }
		.k_int { '`int`' }
		.k_long { '`long`' }
		.k_register { '`register`' }
		.k_restrict { '`restrict`' }
		.k_return { '`return`' }
		.k_short { '`short`' }
		.k_signed { '`signed`' }
		.k_sizeof { '`signed`' }
		.k_static { '`static`' }
		.k_struct { '`struct`' }
		.k_switch { '`switch`' }
		.k_typedef { '`typedef`' }
		.k_union { '`union`' }
		.k_unsigned { '`unsigned`' }
		.k_void { '`void`' }
		.k_volatile { '`volatile`' }
		.k_while { '`while`' }
	}
}

[inline]
pub fn (k Kind) is_assign() bool {
	return int(k) >= int(Kind.assign) && int(k) <= int(Kind.rs_assign)
}

[inline]
pub fn (k Kind) is_keyword() bool {
	return int(k) >= int(Kind.k_alignas)
}

[inline]
pub fn (k Kind) is_type_keyword() bool {
	return k in [.k_char, .k_const, .k_double, .k_enum, .k_float, .k_int, .k_long, .k_short,
		.k_signed, .k_struct, .k_union, .k_unsigned, .k_void, .k_bool, .k_complex, .k_imaginary]
}

pub const (
	reserves = [
		'_Alignas',
		'_Atomic',
		'_Bool',
		'_Complex',
		'_Generic',
		'_Imaginary',
		'_Noreturn',
		'_Static_assert',
		'_Thread_local',
		'alignof',
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
		'short',
		'signed',
		'sizeof',
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
