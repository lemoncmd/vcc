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
