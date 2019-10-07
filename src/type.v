module main

struct Type {
mut:
  kind []Typekind
}

enum Typekind {
  int
  pointer
}
