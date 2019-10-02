import os

fn main(){
  args := os.args
  if args.len != 2 {
    eprintln('The number of arguments is not correct. It must be one.')
    exit(1)
  }
  
  program := args[1]
  mut pos := 0

  mut start_pos := pos
  for pos < program.len && program[pos].is_digit() {
    pos++
  }
  mut number := program.substr(start_pos, pos)
  println('.intel_syntax noprefix
.global main
main:
  mov rax, $number')
  for pos < program.len {
    if program[pos] == `+` {
      pos++
      start_pos = pos
      for pos < program.len && program[pos].is_digit() {
        pos++
      }
      number = program.substr(start_pos, pos)
      println('  add rax, $number')
      continue
    }

    if program[pos] == `-` {
      pos++
      start_pos = pos
      for pos < program.len && program[pos].is_digit() {
        pos++
      }
      number = program.substr(start_pos, pos)
      println('  sub rax, $number')
      continue
    }

    eprintln('Unexpected character: ${program[pos]}')
    exit(1)
  }
  
  println('  ret')
}
