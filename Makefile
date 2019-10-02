CC := v

vcc: main.v

test: vcc
	./test.sh

clean:
	rm -f vcc tmp*
