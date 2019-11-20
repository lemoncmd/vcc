module main

struct Type {
mut:
  kind []Typekind
  suffix []int
  strc []Strcwrap
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
  bool
}

fn (p mut Parser) consume_type() (bool, &Type, string) {
  is_typ, typ := p.consume_type_base()
  if !is_typ {
    return false, typ, ''
  }
  p.consume_type_front(mut typ)
  name := p.expect_ident()
  p.consume_type_back(mut typ)
  return true, typ, name
}

fn (p mut Parser) consume_type_base() (bool, &Type) {
  mut token := p.tokens[p.pos]
  mut typ := &Type{}
  if token.kind != .reserved || !(token.str in ['int', 'long', 'short', 'char', 'struct', 'const', 'void', 'unsigned', 'signed', '_Bool']) {
    return false, typ
  }
  for p.consume('const') {
    token = p.tokens[p.pos]
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

fn (p mut Parser) consume_type_front(typ mut Type) {
  mut token := p.tokens[p.pos]
  for token.kind == .reserved && token.str == '*' {
    typ.kind << Typekind.ptr
    p.pos++
    token = p.tokens[p.pos]
    for p.consume('const') {}
  }
}

fn (p mut Parser) consume_type_back(typ mut Type) {
  if p.consume('[') {
    number := p.expect_number()
    p.expect(']')
    p.consume_type_back(mut typ)
    typ.kind << Typekind.ary
    typ.suffix << number
  }
}

fn (p mut Parser) expect_type() string {
  token := p.tokens[p.pos]
  if token.kind != .reserved || !(token.str in ['int', 'short', 'long', 'char', 'void', '_Bool']) {
    unexp_err(token, 'Expected type but got ${token.str}')
  }
  p.pos++
  return token.str
}

fn (p mut Parser) consume_type_struct() &Type {
  mut typ := &Type{}
  typ.kind << Typekind.strc
  is_ident, name := p.consume_ident()
  mut is_decl := false
  if is_ident {
    is_struct, strc, is_curbl := p.find_struct(name)
    if is_struct {
      if is_curbl {
        if p.consume('{') {
          parse_err('struct $name is already declared in the block')
        }
        typ.strc << Strcwrap{strc}
        return typ
      }
      if p.consume('{') {
        is_decl = true
      } else {
        typ.strc << Strcwrap{strc}
        return typ
      }
    } else {
      if p.consume('{') {
        is_decl = true
      }
    }
  }
  if is_decl {
    mut strc := &Struct{name:name, kind:.strc}
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
          p.consume_type_front(mut typ_child)
          name_child := p.expect_ident()
          if name_child in strc.content {
            parse_err('duplicated member $name')
          }
          p.consume_type_back(mut typ_child)
          strc.offset = align(strc.offset, typ_child.size())
          lvar := &Lvar{name_child, typ_child, false, false, false, strc.offset}
          strc.offset += typ_child.size()
          strc.content[name_child] = Lvarwrap{lvar}
        }
      } else {
        parse_err('expected type')
      }
    }
  }
  return &Type{}
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

fn (typ Type) size() int {
  kind := typ.kind.last()
  if kind == .void {
    parse_err('Cannot use incomplete type void')
  }
  size := match kind {
    .bool, .char, .uchar {1}
    .short, .ushort {2}
    .int, .uint {4}
    .long, .ll, .ulong, .ull, .ptr {8}
    .ary {typ.suffix.last() * typ.reduce().size()}
    else {8}
  }
  return size
}

fn (typ Type) size_allow_void() int {
  if typ.kind.last() == .void {
    return 1
  } else {
    return typ.size()
  }
}

fn (typ Type) reduce() &Type {
  mut typ2 := &Type{}
  typ2.kind = typ.kind.clone()
  typ2.suffix = typ.suffix.clone()
  if typ2.kind.last() == .ary {
    typ2.suffix.delete(typ2.suffix.len-1)
  }
  typ2.kind.delete(typ2.kind.len-1)
  return typ2
}

fn (typ Type) clone() &Type {
  mut typ2 := &Type{}
  typ2.kind = typ.kind.clone()
  typ2.suffix = typ.suffix.clone()
  return typ2
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
      if node.left.typ.kind.last() == .void || node.right.typ.kind.last() == .void {
        node.typ.kind << Typekind.void
      } else {
        bigtyp := type_max(node.left.typ, node.right.typ)
        node.typ = bigtyp.cast_ary()
      }
    }
    .incb, .decb, .incf, .decf, .shl, .shr, .bitnot {
      if (node.kind in [.shl, .shr, .bitnot] && node.left.typ.is_ptr()) || ((node.kind in [.shl, .shr]) && node.right.typ.is_ptr()) {
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
        typ.kind = node.left.typ.kind.clone()
        typ.suffix = node.left.typ.suffix.clone()
        typ = typ.reduce()
      } else {
        typ.kind << Typekind.int
      }
      node.typ = typ
    }
    .addr {
      typ.kind = node.left.typ.kind.clone()
      typ.suffix = node.left.typ.suffix.clone()
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
