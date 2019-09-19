.PHONY: clean

check: envbak.sh
	shellcheck $< 

clean: 
	rm -v !("LICENSE"|"README.md"|"envbak.sh"|"Makefile")
