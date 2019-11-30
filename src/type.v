module main

const (
  Types = ['int', 'long', 'short', 'char', 'struct', 'void', 'unsigned', 'signed', '_Bool']
)

struct Type {
mut:
  kind []Typekind
  suffix []int
  strc []Strcwrap
  func []Funcargwrap
}

enum Typekind {
  void
  int
  char
  short
  long
  ll
  uint
  uchar
  ushort
  ulong
  ull
  ptr
  ary
  strc
  func
  bool
}

fn (p mut Parser) consume_type() (bool, &Type, string) {
  is_typ, mut typ := p.consume_type_base()
  if !is_typ {
    return false, typ, ''
  }
  typb, name := p.consume_type_body()
  typ.merge(typb)
  if name == '' {
    p.token_err('There must be name in the definition')
  }
  p.check_func_typ(typ)
  return true, typ, name
}

fn (p mut Parser) consume_type_allow_no_ident() (bool, &Type, string) {
  is_typ, mut typ := p.consume_type_base()
  if !is_typ {
    return false, typ, ''
  }
  typb, name := p.consume_type_body()
  typ.merge(typb)
  p.check_func_typ(typ)
  return true, typ, name
}

fn (p mut Parser) consume_type_body() (&Type, string) {
  mut typ := p.consume_type_front()
  mut name := ''
  if !p.look_for_bracket() && !p.look_for_bracket_with_type() && p.consume('(') {
    typb, str := p.consume_type_body()
    p.consume(')')
    name = str
    typ.merge(p.consume_type_back())
    typ.merge(typb)
  } else {
    _, name = p.consume_ident()
    typ.merge(p.consume_type_back())
  }
  return typ, name
}

fn (p mut Parser) consume_type_nostring() (bool, &Type) {
  is_typ, mut typ := p.consume_type_base()
  if !is_typ {
    return false, typ
  }
  typ.merge(p.consume_type_body_nostring())
  p.check_func_typ(typ)
  return true, typ
}

fn (p mut Parser) consume_type_body_nostring() &Type {
  mut typ := p.consume_type_front()
  if !p.look_for_bracket() && !p.look_for_bracket_with_type() && p.consume('(') {
    typb := p.consume_type_body_nostring()
    p.consume(')')
    typ.merge(p.consume_type_back())
    typ.merge(typb)
  } else {
    typ.merge(p.consume_type_back())
  }
  return typ
}

fn (p mut Parser) consume_type_base() (bool, &Type) {
  mut token := p.tokens[p.pos]
  mut typ := &Type{}
  for p.consume('const') {
    token = p.tokens[p.pos]
  }
  is_lvar, lvar, _ := p.find_lvar(token.str)
  if token.kind != .reserved || !token.str in Types {
    if is_lvar && lvar.is_type {
      p.pos++
      for p.consume('const') {}
      return true, lvar.typ.clone()
    } else {
      return false, typ
    }
  }
  is_signed := p.consume('signed')
  is_unsigned := p.consume('unsigned')
  if (is_signed && is_unsigned) || (is_unsigned && p.consume('signed')) {
    p.token_err('Type cannot be signed and unsigned')
  }
  if is_signed || is_unsigned {
    token = p.tokens[p.pos]
  }
  for p.consume('const') {
    token = p.tokens[p.pos]
  }
  if token.str == 'struct'{
    if is_signed || is_unsigned {
      p.token_err('Struct cannot be signed or unsigned')
    }
    p.pos++
    typ = p.consume_type_struct()
  } else if token.str == '_Bool' {
    if is_signed || is_unsigned {
      p.token_err('_Bool cannot be signed or unsigned')
    }
    p.pos++
    typ.kind << Typekind.bool
  } else {
    p.pos++
    match token.str {
      'void' {
        typ.kind << Typekind.void
      }
      'char' {
        typ.kind << Typekind.char
      }
      'int' {
        typ.kind << Typekind.int
      }
      'short' {
        for p.consume('const') {}
        p.consume('int')
        typ.kind << Typekind.short
      }
      'long' {
        for p.consume('const') {}
        if p.consume('long') {
          typ.kind << Typekind.ll
        } else {
          typ.kind << Typekind.long
        }
        for p.consume('const') {}
        p.consume('int')
      }
    }
    if is_unsigned {
      old_kind := typ.kind[0]
      typ.kind[0] = match old_kind {
        .void  {Typekind.void}
        .int   {Typekind.uint}
        .char  {Typekind.uchar}
        .short {Typekind.ushort}
        .long  {Typekind.ulong}
        .ll    {Typekind.ull}
        else   {.void}
      }
    }
  }
  for p.consume('const') {}
  return true, typ
}

fn (p mut Parser) consume_type_front() &Type {
  mut typ := &Type{}
  mut token := p.tokens[p.pos]
  for token.kind == .reserved && token.str == '*' {
    typ.kind << Typekind.ptr
    p.pos++
    token = p.tokens[p.pos]
    for p.consume('const') {}
  }
  return typ
}

fn (p mut Parser) consume_type_back() &Type {
  mut typ := &Type{}
  if p.consume('[') {
    number := if p.consume(']') {
      -1
    } else if p.consume('*') {
      0
    } else {
      p.expect_number()
    }
    if number != -1 {
      p.expect(']')
    }
    typ = p.consume_type_back()
    typ.kind << Typekind.ary
    typ.suffix << number
  } else if p.consume('(') {
    mut first := true
    mut paras := []string
    mut args := &Funcarg{}
    for !p.consume(')') {
      if first {
        if p.consume('void') {
          p.expect(')')
          break
        }
        first = false
      } else {
        p.expect(',')
      }
      if p.consume('...') {
        p.expect(')')
        break
      }
      is_typ, mut argtyp, name := p.consume_type_allow_no_ident()
      if !is_typ {
        p.token_err('Expected type')
      }
      if argtyp.kind.last() == .ary {
        argtyp = argtyp.reduce()
        argtyp.size()
        argtyp.kind << Typekind.ptr
      }
      if argtyp.kind.last() == .func {
        argtyp.kind << Typekind.ptr
      }
      if name in paras {
        p.token_err('Parameter `$name` is already declared')
      }
      if name != '' {
        paras << name
      }
      lvar := p.new_lvar(name, argtyp, 0)
      args.args << Lvarwrap{lvar}
    }
    typ = p.consume_type_back()
    typ.kind << Typekind.func
    typ.func << Funcargwrap{args}
  }
  return typ
}

fn (p mut Parser) expect_type() string {
  token := p.tokens[p.pos]
  if token.kind != .reserved || !token.str in Types {
    unexp_err(token, 'Expected type but got ${token.str}')
  }
  p.pos++
  return token.str
}

fn (p Parser) look_for_bracket() bool {
  if !p.look_for('(') {return false}
  if p.tokens[p.pos+1].kind == .reserved && p.tokens[p.pos+1].str == ')' {
    return true
  }
  return false
}

fn (p Parser) look_for_bracket_with_type() bool {
  if !p.look_for('(') {return false}
  if p.tokens[p.pos+1].kind in [.reserved, .ident] {
    str := p.tokens[p.pos+1].str
    if str in Types {
      return true
    } else {
      is_lvar, lvar, _ := p.find_lvar(str)
      if is_lvar && lvar.is_type {
        return true
      }
    }
  }
  return false
}

fn (p mut Parser) consume_type_struct() &Type {
  mut typ := &Type{kind:[Typekind.strc]}
  is_ident, name := p.consume_ident()
  mut is_protoed := false
  if is_ident {
    is_struct, mut strc, is_curbl := p.find_struct(name)
    if is_struct {
      if is_curbl && strc.is_defined {
        if p.consume('{') {
          parse_err('struct $name is already declared in the block')
        }
        typ.strc << Strcwrap{strc}
        return typ
      }
      if p.consume('{') {
        is_protoed = is_curbl && !strc.is_defined
      } else {
        typ.strc << Strcwrap{strc}
        return typ
      }
    } else {
      if !p.consume('{') {
        strc2 := &Struct{name:name, kind:.strc}
        if p.curbl.len == 0 {
          p.glstrc[name] = Strcwrap{strc2}
        } else {
          mut curbl := (p.curbl.last()).val
          curbl.structs[name] = Strcwrap{strc2}
        }
        typ.strc << Strcwrap{strc2}
        return typ
      }
    }
  } else {
    p.expect('{')
  }
  _, _strc, _ := p.find_struct(name)
  mut strc := if is_protoed {
    _strc
  } else {
    &Struct{name:name, kind:.strc}
  }
  if !is_protoed && name != '' {
    if p.curbl.len == 0 {
      p.glstrc[name] = Strcwrap{strc}
    } else {
      mut curbl := (p.curbl.last()).val
      curbl.structs[name] = Strcwrap{strc}
    }
  }
  mut max_align := 1
  for !p.consume('}') {
    is_dec, typ_base := p.consume_type_base()
    if is_dec {
      mut first := true
      for !p.consume(';') {
        mut typ_child := typ_base.clone()
        if first {
          first = false
        } else {
          p.expect(',')
        }
        typ_child.merge(p.consume_type_front())
        name_child := p.expect_ident()
        if name_child in strc.content {
          parse_err('duplicated member $name')
        }
        typ_child.merge(p.consume_type_back())
        strc.offset = align(strc.offset, typ_child.size_align())
        max_align = if typ_child.size_align() > max_align {typ_child.size_align()} else {max_align}
        lvar := &Lvar{name_child, typ_child, false, false, false, false, strc.offset}
        strc.offset += typ_child.size()
        strc.content[name_child] = Lvarwrap{lvar}
      }
    } else {
      parse_err('expected type')
    }
  }
  strc.is_defined = true
  strc.max_align = max_align
  strc.offset = align(strc.offset, max_align)
  typ.strc << Strcwrap{strc}
  return typ
}

fn (p Parser) check_func_typ(_typ &Type) {
  mut typ := _typ.clone()
  mut is_func := false
  for typ.kind.len != 0 {
    if is_func && typ.kind.last() in [.func, .ary] {
      p.token_err('Function cannot return type `${typ.str()}`')
    }
    is_func = typ.kind.last() == .func
    typ = typ.reduce()
  }
}

fn align(offset, size int) int {
  return (offset+size-1) & ~(size-1)
}

fn (typ Type) is_unsigned() bool {
  kind := typ.kind.last()
  if kind in [.uint, .uchar, .ushort, .ulong, .ull, .ptr] {
    return true
  }
  return false
}

fn (typ Type) str() string {
  match typ.kind.last() {
    .void   { return 'void' }
    .int    { return 'int' }
    .char   { return 'char' }
    .short  { return 'short' }
    .long   { return 'long' }
    .ll     { return 'long long' }
    .uint   { return 'unsigned int' }
    .uchar  { return 'unsigned char' }
    .ushort { return 'unsigned short' }
    .ulong  { return 'unsigned long' }
    .ull    { return 'unsigned long long' }
    .ptr    { return '*'+typ.reduce().str() }
    .ary    {
      last := if typ.suffix.last() < 0 {''} else {'${typ.suffix.last()}'}
      return '[${last}]'+typ.reduce().str()
    }
    .strc   { return '' } //todo
    .bool   { return '_Bool' }
    .func   {
      args := typ.func.last()
      mut strs := []string
      for lvar in args.val.args {
        strs << lvar.val.typ.str()
      }
      str := strs.join(', ')
      return 'fn($str) '+typ.reduce().str()
    }
    else { parse_err('Something wrong with type') }
  }
  return ''
}

fn (typ Type) size() int {
  kind := typ.kind.last()
  if kind == .void {
    parse_err('Cannot use incomplete type `void`')
  }
  if kind == .strc {
    strc := (typ.strc.last()).val
    if !strc.is_defined {
      parse_err('Incomplete struct ${strc.name}')
    } else {
      return strc.offset
    }
  }
  size := match kind {
    .bool, .char, .uchar {1}
    .short, .ushort {2}
    .int, .uint {4}
    .long, .ll, .ulong, .ull, .ptr, .func {8}
    .ary {typ.suffix.last() * typ.reduce().size()}
    else {8}
  }
  if size < 0 {
    parse_err('Cannot use incomplete type `$typ`')
  }
  return size
}

fn (typ Type) size_allow_void() int {
  if typ.kind.last() in [.void, .func] {
    return 1
  } else {
    return typ.size()
  }
}

fn (typ Type) size_align() int {
  if typ.kind.last() == .ary {
    return typ.reduce().size_align()
  } else if typ.kind.last() == .strc {
    return (typ.strc.last()).val.max_align
  } else {
    return typ.size()
  }
}

fn (typ Type) reduce() &Type {
  mut typ2 := typ.clone()
  if typ2.kind.last() == .ary {
    typ2.suffix.delete(typ2.suffix.len-1)
  } else if typ2.kind.last() == .strc {
    typ2.strc.delete(typ2.strc.len-1)
  } else if typ2.kind.last() == .func {
    typ2.func.delete(typ2.func.len-1)
  }
  typ2.kind.delete(typ2.kind.len-1)
  return typ2
}

fn (typ Type) clone() &Type {
  return &Type{
    kind:typ.kind.clone()
    suffix:typ.suffix.clone()
    strc:typ.strc.clone()
    func:typ.func.clone()
  }
}

fn (typ Type) cast_ary() &Type {
  mut typ2 := typ.clone()
  if typ.kind.last() != .ary {
    return typ2
  }
  typ2 = typ2.reduce()
  typ2.kind << Typekind.ptr
  return typ2
}

fn (typ mut Type) merge(typ2 &Type) {
  typ.kind << typ2.kind
  typ.suffix << typ2.suffix
  typ.strc << typ2.strc
  typ.func << typ2.func
}

fn (typ Type) is_int() bool {
  return typ.kind.last() in [.char, .short, .int, .long, .ll, .uchar, .ushort, .uint, .ulong, .ull, .bool]
}

fn (typ Type) is_ptr() bool {
  return typ.kind.last() == .ptr || typ.kind.last() == .ary
}

fn type_max(typ1, typ2 &Type) &Type {
  mut typ := &Type{}
  mut mtyp1 := typ1.clone()
  mut mtyp2 := typ2.clone()
  typ.kind << Typekind.int
  if typ1.size() < 4 {
    mtyp1 = typ
  }
  if typ2.size() < 4 {
    mtyp2 = typ
  }
  if mtyp1.size() > mtyp2.size() {
    return mtyp1
  } else if mtyp1.size() == mtyp2.size() {
    if mtyp2.is_unsigned() {
      return mtyp2
    }
    return mtyp1
  } else {
    return mtyp2
  }
}

fn (node mut Node) add_type() {
  if node.kind == .nothing || node.typ != 0 {
    return
  }
  if !isnil(node.cond) {node.cond.add_type()}
  if !isnil(node.first) {node.first.add_type()}
  if !isnil(node.left) {node.left.add_type()}
  if !isnil(node.right) {node.right.add_type()}

  for i in node.code {
    mut no := &Node(i)
    no.add_type()
  }

  mut typ := &Type{}

  match(node.kind) {
    .assign, .calcassign {
      node.typ = node.left.typ.clone()
    }
    .eq, .ne, .gt, .ge, .num {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .add, .sub, .mul, .div, .mod, .bitand, .bitor, .bitxor {
      bigtyp := type_max(node.left.typ, node.right.typ)
      if node.left.typ.is_ptr() || node.right.typ.is_ptr() {
        parse_err('Invalid operand type')
      }
      node.typ = bigtyp.cast_ary()
    }
    .ifelse {
      if node.name == 'stmt' {
        return
      }
      if node.left.typ.kind.last() == .void || node.right.typ.kind.last() == .void {
        node.typ.kind << Typekind.void
      } else {
        bigtyp := type_max(node.left.typ, node.right.typ)
        node.typ = bigtyp.cast_ary()
      }
    }
    .incb, .decb, .incf, .decf, .shl, .shr, .bitnot {
      if (node.kind in [.shl, .shr, .bitnot] && node.left.typ.is_ptr()) || (node.kind in [.shl, .shr] && node.right.typ.is_ptr()) {
        parse_err('Invalid operand type')
      }
      node.typ = node.left.typ.cast_ary()
    }
    .comma {
      node.typ = node.right.typ.cast_ary()
    }
    .call {
      typ.kind << Typekind.ulong
      node.typ = typ
    }
    .sizof {
      typ.kind << Typekind.ulong
      node.typ = typ
    }
    .deref {
      if node.left.typ.is_ptr() {
        typ = node.left.typ.reduce()
      } else if node.left.typ.kind.last() == .func {
        typ = node.left.typ.clone()
      } else {
        typ.kind << Typekind.int
      }
      node.typ = typ
    }
    .addr {
      typ = node.left.typ.clone()
      if typ.kind.last() == .ary {
        typ = typ.reduce()
      }
      typ.kind << Typekind.ptr
      node.typ = typ
    }
    .string {
      typ.kind << Typekind.char
      typ.kind << Typekind.ary
      typ.suffix << node.name.len+1
      node.typ = typ
    }
  }
}
