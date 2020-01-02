module token

pub struct Token {
pub:
  kind Kind
  str string
  line int
  pos int
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

pub const (
  reserves = [
  '_Bool', '_Complex', '_Imaginary',
  'auto', 'break', 'case', 'char', 'const', 'continue', 'default', 'do',
  'double', 'else', 'enum', 'extern', 'float', 'for', 'goto', 'if',
  'inline', 'int', 'long', 'register', 'restrict', 'return', 'signed',
  'sizeof', 'short', 'static', 'struct', 'switch', 'typedef', 'union',
  'unsigned', 'void', 'volatile', 'while'
  ]
)

