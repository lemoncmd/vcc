module main

import (
  src2.scanner as scanner
)

fn main() {
  mut s := &scanner.Scanner{'hoge',0,1,0}
  token := s.scan()
  println(token.str)
}
