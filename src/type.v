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
/*
fn (p mut Parser) consume_struct() {
  is_ident, name := p.consume_ident()
  if is_ident {
    is_struct, strc := p.find_struct(name)

*/

fn (typ Type) size() int {
  kind := typ.kind.last()
  size := match kind {
    .char => {1}
    .short => {2}
    .int => {4}
    .long => {4}
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
