#!/bin/bash
try() {
  expected="$1"
  input="$2"

  ./vcc "$input" > tmp.s
  gcc -o tmp tmp.s
  ./tmp
  actual="$?"

  if [ "$actual" = "$expected" ]; then
    echo "$input => $actual"
  else
    echo "$input => $expected expected, but got $actual"
    exit 1
  fi
}

try 0 '0;'
try 42 '42;'
try 21 "5+20-4;"
try 41 " 12 + 34 - 5 ;"
try 47 '5+6*7;'
try 15 '5*(9-6);'
try 4 '(3+5)/2;'
try 7 '-3+10;'
try 7 '-3++10;'
try 7 '-3--10;'
try 12 '-(3+5)+20;'
try 30 '-3*+5*-2;'
try 1 '1+1==2;'
try 0 '1+1==3;'
try 1 '2>1;'
try 1 '43>=43;'
try 0 '(0<1)*2!=2;'
try 1 '1>2==3>=4;'
try 5 'foo=2;bar=4-1;foo=foo+bar;foo;'
try 3 'foo=2;return bar=4-1;foo=foo+bar;foo;'
try 2 'foo=bar=2;return foo;'
try 4 'returna = 3; _1_ = returna + 1; return _1_;'
try 6 'ife = 2; if(ife > 5) return ife; else return 6;'
try 7 'ife = 7; if(ife > 5) return ife; else return 6;'
try 23 'if(1)a=23; return a;'
try 34 'hoge = 3; if(hoge > 6) return 23; else if (hoge>2) return 34; else return 45;'
try 22 'huga=3;if(huga>1)if(huga<5)return 22;return 4;'
try 4 'huga=1;if(huga>1)if(huga<5)return 22;return 4;'
try 4 'huga=7;if(huga>1)if(huga<5)return 22;return 4;'
try 45 'foo = 0; for(i=0; i<10; i=i+1)foo=foo+i;return foo;'
try 11 'foo = 0; for(;;)if((foo=foo+1)>10)return foo;'
try 55 'foo = i = 0; while(i<10)foo=foo+(i=i+1);return foo;'
try 45 'foo = i = 0; while(i<10){foo=foo+i;i=i+1;}return foo;'
try 15 'foo=0;for(i=0; i<10; i=i+1){if(i-i/2*2==1){foo=foo+1;}else{foo=foo+2;}}return foo;'

echo OK
