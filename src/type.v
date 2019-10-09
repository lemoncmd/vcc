module main

struct Type {
mut:
  kind []Typekind
}

enum Typekind {
  int
  char
  ptr
}

fn (typ Type) size() int {
  kind := typ.kind.last()
  size := match kind {
    .int => {4}
    .ptr => {8}
    else => {8}
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
