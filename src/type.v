module main

struct Type {
mut:
  kind []Typekind
}

enum Typekind {
  int
  ptr
}

fn (typ Type) size() int {
  kind := typ.kind.last()
  size := if kind == .int {
    4
  } else {
    8
  }
  return size
}

fn (typ Type) is_int() bool {
  return typ.kind.last() == .int
}

fn (typ Type) is_ptr() bool {
  return typ.kind.last() == .ptr
}

fn (node mut Node) add_type() {
  if node.kind == .nothing || node.typ != 0 {
    return
  }
  node.cond.add_type()
  node.first.add_type()
  node.left.add_type()
  node.right.add_type()

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
      typ.kind << Typekind.int
      node.typ = typ
    }
    .div    => {
      typ.kind << Typekind.int
      node.typ = typ
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
    .lvar   => {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .call   => {
      typ.kind << Typekind.int
      node.typ = typ
    }
    .deref  => {
      if node.left.typ.is_ptr() {
        typ.kind = node.left.typ.kind.clone()
        typ.kind.delete(typ.kind.len-1)
      } else {
        typ.kind << Typekind.int
      }
      node.typ = typ
    }
    .addr   => {
      typ.kind = node.left.typ.kind.clone()
      typ.kind << Typekind.ptr
      node.typ = typ
    }
  }
}
