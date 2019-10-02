vcc:
	v -o vcc main.v

test: vcc
	./test.sh
	make clean

clean:
	rm -f vcc tmp*

.PHONY: test clean
