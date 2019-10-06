#!/bin/bash
cat <<EOF > tmp2.c
#include <stdio.h>
int foo(){return 21;}
int bar(int i, int j){return i+j;}
int hw(){printf("Hello, world!\\n");}
EOF
gcc -c -o tmp2.o tmp2.c
try() {
  expected="$1"
  input="$2"

  ./vcc "$input" > tmp.s
  gcc -o tmp tmp.s tmp2.o
  ./tmp
  actual="$?"

  if [ "$actual" = "$expected" ]; then
    echo "$input => $actual"
  else
    echo "$input => $expected expected, but got $actual"
    exit 1
  fi
}

try 0  'int main(){return 0;}'
try 42 'int main(){return 42;}'
try 21 "int main(){return 5+20-4;}"
try 41 "int main(){return  12 + 34 - 5 ;}"
try 47 'int main(){return 5+6*7;}'
try 15 'int main(){return 5*(9-6);}'
try 4  'int main(){return (3+5)/2;}'
try 7  'int main(){return -3+10;}'
try 7  'int main(){return -3++10;}'
try 7  'int main(){return -3--10;}'
try 12 'int main(){return -(3+5)+20;}'
try 30 'int main(){return -3*+5*-2;}'
try 1  'int main(){return 1+1==2;}'
try 0  'int main(){return 1+1==3;}'
try 1  'int main(){return 2>1;}'
try 1  'int main(){return 43>=43;}'
try 0  'int main(){return (0<1)*2!=2;}'
try 1  'int main(){return 1>2==3>=4;}'
try 5  'int main(){foo=2;bar=4-1;foo=foo+bar;return foo;}'
try 3  'int main(){foo=2;return bar=4-1;foo=foo+bar;return foo;}'
try 2  'int main(){foo=bar=2;return foo;}'
try 4  'int main(){returna = 3; _1_ = returna + 1; return _1_;}'
try 6  'int main(){ife = 2; if(ife > 5) return ife; else return 6;}'
try 7  'int main(){ife = 7; if(ife > 5) return ife; else return 6;}'
try 23 'int main(){if(1)a=23; return a;}'
try 34 'int main(){hoge = 3; if(hoge > 6) return 23; else if (hoge>2) return 34; else return 45;}'
try 22 'int main(){huga=3;if(huga>1)if(huga<5)return 22;return 4;}'
try 4  'int main(){huga=1;if(huga>1)if(huga<5)return 22;return 4;}'
try 4  'int main(){huga=7;if(huga>1)if(huga<5)return 22;return 4;}'
try 45 'int main(){foo = 0; for(i=0; i<10; i=i+1)foo=foo+i;return foo;}'
try 11 'int main(){foo = 0; for(;;)if((foo=foo+1)>10)return foo;}'
try 55 'int main(){foo = i = 0; while(i<10)foo=foo+(i=i+1);return foo;}'
try 45 'int main(){foo = i = 0; while(i<10){foo=foo+i;i=i+1;}return foo;}'
try 15 'int main(){foo=0;for(i=0; i<10; i=i+1){if(i-i/2*2==1){foo=foo+1;}else{foo=foo+2;}}return foo;}'
try 21 'int main(){return foo();}'
try 42 'int main(){foo=2;return foo()*foo;}'
try 55 'int main(){return foo()*bar(2,3)-50;}'
try 48 'int main(){return hoge()+fuga();}int hoge(){return 32;}int fuga(){hoge=16;return hoge;}'
try 21 'int main(){return fib(7);}int fib(int n){if(n>1)return fib(n-1)+fib(n-2);else return 1;}'
try 23 'int main(){return hoge(4,5);}int hoge(int n,int m){if(n>m)return 12;return 23;}'
try 3  'int main(){x=3;y=&x;return *y;}'
try 3  'int main(){x=3;y=5;z=&y+8;return *z;}'

echo OK
