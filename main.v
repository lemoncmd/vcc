import os

fn main(){
  args := os.args
  if args.len != 2 {
    eprintln('The number of arguments is not correct. It must be one.')
    exit(1)
  }
  
  num := args[1].int()
  program := '.intel_syntax noprefix
.global main
main:
  mov rax, $num
  ret'
  
  println(program)
}
