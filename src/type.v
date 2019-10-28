module main

struct Type {
mut:
  kind []Typekind
  suffix []int
  strc []Strcwrap
}

enum Typekind {
  int
  char
  short
  long
  ll
  ptr
  ary
  strc
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
  token := p.tokens[p.pos]
  mut typ := &Type{}
  if token.kind != .reserved || !(token.str in ['int', 'long', 'short', 'char', 'struct', 'const']) {
    return false, typ
  }
  for p.consume('const') {}
  if token.str == 'struct'{
    typ = p.consume_type_struct()
  } else {
    p.pos++
    match token.str {
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
  if token.kind != .reserved || !(token.str in ['int', 'short', 'long', 'char']) {
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
    mut strc := &Struct{name:name, kind:Structkind.strc}
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
          lvar := &Lvar{name_child, typ_child, false, strc.offset}
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

fn (typ Type) size() int {
  kind := typ.kind.last()
  size := match kind {
    .char {1}
    .short {2}
    .int {4}
    .long, .ll, .ptr {8}
    .ary {typ.suffix.last() * typ.reduce().size()}
    else {8}
  }
  return size
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

fn (typ mut Type) merge(typ2 &Type) {
  typ.kind << typ2.kind
  typ.suffix << typ2.suffix
}

fn (typ Type) is_int() bool {
  return typ.kind.last() in [Typekind.char, .short, .int, .long, .ll]
}

fn (typ Type) is_ptr() bool {
  return typ.kind.last() == .ptr || typ.kind.last() == .ary
}

fn type_max(typ1, typ2 &Type) &Type {
  if typ1.size() > typ2.size() {
    return typ1
  } else {
    return typ2
  }
}

fn (node mut Node) add_type() {
  if node.kind == .nothing || node.typ != 0 {
    return
  }
  if node.cond != 0 {node.cond.add_type()}
  if node.first != 0 {node.first.add_type()}
  if node.left != 0 {node.left.add_type()}
  if node.right != 0 {node.right.add_type()}

  for i in node.code {
    mut no := &Node(i)
    no.add_type()
  }

  mut typ := &Type{}

  match(node.kind) {
    .assign {
      node.typ = node.left.typ
    }
    .add, .sub, .eq, .ne, .gt, .ge, .num {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .mul, .div, .mod {
      bigtyp := type_max(node.left.typ, node.right.typ)
      node.typ = bigtyp.clone()
    }
    .incb, .decb, .incf, .decf {
      node.typ = node.left.typ.clone()
    }
    .call {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .sizof {
      typ.kind << Typekind.int
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
