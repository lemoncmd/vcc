fn try(expected int, input string) {
  write_file('tmp.c', 'int printf(char*,...);int foo();int bar(int,int);int hw();void alloc4(int**,int,int,int,int);'+input)
  system('./vcc tmp.c > tmp.s')
  system('gcc -o tmp tmp.s tmp2.o')
  actual := system('./tmp')/256
  if actual == expected {
    println('$input => $actual')
  } else {
    println('$input => $expected expected, but got $actual')
    exit(1)
  }
}
fn main(){

mut file := create('tmp2.c') or {panic('failed to create tmp2.c')}
file.write('
extern void *malloc(unsigned long int size);
extern int printf(const char * format,...);
int foo(){return 21;}
int bar(int i, int j){return i+j;}
int hw(){printf("Hello, world!\\n");}
void alloc4(int**p, int a, int b, int c, int d){*p=malloc(16);**p=a;*(*p+1)=b;*(*p+2)=c;*(*p+3)=d;}
')
file.close()
system('./vcc tmp2.c > tmp2.s')
system('gcc -c -o tmp2.o tmp2.s')

try(0 , 'int main(){return 0;}')
try(42, 'int main(){return 42;}')
try(21, 'int main(){return 5+20-4;}')
try(41, 'int main(){return  12 + 34 - 5 ;}')
try(47, 'int main(){return 5+6*7;}')
try(15, 'int main(){return 5*(9-6);}')
try(4 , 'int main(){return (3+5)/2;}')
try(7 , 'int main(){return -3+10;}')
try(7 , 'int main(){return -3+ +10;}')
try(7 , 'int main(){return -3- -10;}')
try(12, 'int main(){return -(3+5)+20;}')
try(30, 'int main(){return -3*+5*-2;}')
try(1 , 'int main(){return 1+1==2;}')
try(0 , 'int main(){return 1+1==3;}')
try(1 , 'int main(){return 2>1;}')
try(1 , 'int main(){return 43>=43;}')
try(0 , 'int main(){return (0<1)*2!=2;}')
try(1 , 'int main(){return 1>2==3>=4;}')
try(5 , 'int main(){int foo;int bar;foo=2;bar=4-1;foo=foo+bar;return foo;}')
try(3 , 'int main(){int bar;int foo;foo=2;return bar=4-1;foo=foo+bar;return foo;}')
try(2 , 'int main(){int foo;int bar;foo=bar=2;return foo;}')
try(4 , 'int main(){int returna;returna = 3;int _1_; _1_ = returna + 1; return _1_;}')
try(6 , 'int main(){int ife;ife = 2; if(ife > 5) return ife; else return 6;}')
try(7 , 'int main(){int ife;ife = 7; if(ife > 5) return ife; else return 6;}')
try(23, 'int main(){int a;if(1)a=23; return a;}')
try(34, 'int main(){int hoge;hoge = 3; if(hoge > 6) return 23; else if (hoge>2) return 34; else return 45;}')
try(22, 'int main(){int huga;huga=3;if(huga>1)if(huga<5)return 22;return 4;}')
try(4 , 'int main(){int huga;huga=1;if(huga>1)if(huga<5)return 22;return 4;}')
try(4 , 'int main(){int huga;huga=7;if(huga>1)if(huga<5)return 22;return 4;}')
try(45, 'int main(){int foo;int i;foo = 0; for(i=0; i<10; i=i+1)foo=foo+i;return foo;}')
try(11, 'int main(){int foo;foo = 0; for(;;)if((foo=foo+1)>10)return foo;}')
try(55, 'int main(){int foo;int i;foo = i = 0; while(i<10)foo=foo+(i=i+1);return foo;}')
try(45, 'int main(){int foo;int i;foo = i = 0; while(i<10){foo=foo+i;i=i+1;}return foo;}')
try(15, 'int main(){int foo;int i;foo=0;for(i=0; i<10; i=i+1){if(i-i/2*2==1){foo=foo+1;}else{foo=foo+2;}}return foo;}')
try(21, 'int main(){return foo();}')
try(42, 'int main(){int foo2;foo2=2;return foo()*foo2;}')
try(55, 'int main(){return foo()*bar(2,3)-50;}')
try(48, 'int fuga(),hoge();int main(){return hoge()+fuga();}int hoge(){return 32;}int fuga(){int hoge;hoge=16;return hoge;}')
try(21, 'int fib(int);int main(){return fib(7);}int fib(int n){if(n>1)return fib(n-1)+fib(n-2);else return 1;}')
try(23, 'int hoge(int,int);int main(){return hoge(4,5);}int hoge(int n,int m){if(n>m)return 12;return 23;}')
try(3 , 'int main(){int x;int *y;x=3;y=&x;return *y;}')
try(3 , 'int main(){int x;int y;int *z;x=3;y=5;z=&y+1;return *z;}')
try(3 , 'int main(){int x;int *y;y=&x;*y=3;return x;}')
try(4 , 'int main(){int *p;alloc4(&p, 1, 2, 4, 8);int *q;q=p+2;return *q;}')
try(8 , 'int main(){int *p;alloc4(&p, 1, 2, 4, 8);int *q;q=p+3;return *q;}')
try(4 , 'int main(){return sizeof(1);}')
try(8 , 'int main(){int *x;return sizeof(x);}')
try(4 , 'int main(){int *x;return sizeof(*x);}')
try(4 , 'int val,hoge();int main(){hoge();return val;}int hoge(){int hoge=4; val = hoge;}')
try(4 , 'int main(){char a=1;short int b=2; int c=3; long d=4; long long int e=5; return d;}')
try(111,'int main(){char *a="hgoe"; printf(a); printf("hgoee"); return a[2];}')
try(12, 'int main(){return (3%2)?12:5;}')
try(5 , 'int main(){return 0+0?12:5;}')
try(1 , 'int main(){int a=1;{int a=2;{int a=3;}}return a;}')
try(2 , 'int main(){int a=1;{int a=2;{int a=3;}return a;}}')
try(3 , 'int main(){int a=1;{int a=2;{int a=3;return a;}}}')
try(3 , 'int main(){int a=1,b=2,c=3,d=4;return c;}')
try(45, 'int main(){int a=0; for(int i=0; i<10; i++)a=a+i;return a;}')
try(3 , 'int main(){for(;;)break;return 3;}')
try(45, 'int main(){int a=0; for(int i=0;;i++){if(i<10){a=a+i;continue;}else{break;}}return a;}')
try(10, 'int main(){int a=0; while(++a<10);return a;}')
try(55, 'int main(){int a=0, i=0; do{i++;a=a+i;}while(i<10);return a;}')
try(54, 'int main(){int a=0;for(int i=0;i<10;i++){for(int j=0;j<10;j++){a=a+i;if(a>52){goto hoge;}}}hoge:return a;}')
try(1 , 'int main(){return \'b\' - \'\\n\' == \'X\';}')
try(10, 'int pluser();int main(){int a=0;for(int i=0;i<10;i++)a=pluser();return a;}int pluser(){static int hoge;hoge++;return hoge;}')
try(0 , 'int main(){return ~-!0;}')

println('OK')
}
