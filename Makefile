.PHONY: clean

check: envbak.sh
	shellcheck $< 

clean:
	find . -type f -not -name 'envbak.sh' -not -name 'Makefile' -not -name 'README.md' -not -name 'LICENSE' -delete
	find . -type d -not -name '.git' -delete
