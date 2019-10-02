vcc:
	v -o vcc main.v

test: vcc
	./test.sh

clean:
	rm -f vcc tmp*

.PHONY: test clean
