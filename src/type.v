module main

struct Type {
mut:
  kind []Typekind
  suffix []int
}

enum Typekind {
  int
  char
  short
  long
  ll
  ptr
  ary
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
  if token.kind != .reserved || !(token.str in ['int', 'long', 'short', 'char', 'struct']) {
    return false, typ
  }
  if token.str == 'struct'{
 //   p.consume_type_struct()
  } else {
    p.pos++
    match token.str {
      'char' => {
        typ.kind << Typekind.char
      }
      'int' => {
        typ.kind << Typekind.int
      }
      'short' => {
        p.consume('int')
        typ.kind << Typekind.short
      }
      'long' => {
        if p.consume('long') {
          typ.kind << Typekind.ll
        } else {
          typ.kind << Typekind.long
        }
        p.consume('int')
      }
    }
  }
  return true, typ
}

fn (p mut Parser) consume_type_front(typ mut Type) {
  mut token := p.tokens[p.pos]
  for token.kind == .reserved && token.str == '*' {
    typ.kind << Typekind.ptr
    p.pos++
    token = p.tokens[p.pos]
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

/*
fn (p mut Parser) consume_struct() {
  is_ident, name := p.consume_ident()
  if is_ident {
    is_struct, strc := p.find_struct(name)

*/

fn align(offset, size int) int {
  return (offset+size-1) & ~(size-1)
}

fn (typ Type) size() int {
  kind := typ.kind.last()
  size := match kind {
    .char => {1}
    .short => {2}
    .int => {4}
    .long => {8}
    .ll => {8}
    .ptr => {8}
    .ary => {typ.suffix.last() * typ.reduce().size()}
    else => {8}
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
    .assign => {
      node.typ = node.left.typ
    }
    .add    => {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .sub    => {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .mul    => {
      bigtyp := type_max(node.left.typ, node.right.typ)
      node.typ = bigtyp.clone()
    }
    .div    => {
      bigtyp := type_max(node.left.typ, node.right.typ)
      node.typ = bigtyp.clone()
    }
    .mod    => {
      bigtyp := type_max(node.left.typ, node.right.typ)
      node.typ = bigtyp.clone()
    }
    .eq     => {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .ne     => {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .gt     => {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .ge     => {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .num    => {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .incb   => {
      node.typ = node.left.typ.clone()
    }
    .decb   => {
      node.typ = node.left.typ.clone()
    }
    .incf   => {
      node.typ = node.left.typ.clone()
    }
    .decf   => {
      node.typ = node.left.typ.clone()
    }
    .call   => {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .sizof  => {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .deref  => {
      if node.left.typ.is_ptr() {
        typ.kind = node.left.typ.kind.clone()
        typ.suffix = node.left.typ.suffix.clone()
        typ = typ.reduce()
      } else {
        typ.kind << Typekind.int
      }
      node.typ = typ
    }
    .addr   => {
      typ.kind = node.left.typ.kind.clone()
      typ.suffix = node.left.typ.suffix.clone()
      if typ.kind.last() == .ary {
        typ = typ.reduce()
      }
      typ.kind << Typekind.ptr
      node.typ = typ
    }
    .string => {
      typ.kind << Typekind.char
      typ.kind << Typekind.ary
      typ.suffix << node.name.len+1
      node.typ = typ
    }
  }
}
