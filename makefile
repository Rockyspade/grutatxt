
PREFIX=/usr/local

all: grutatxt README.html

grutatxt: grutatxt.pl grutatxt.src
	perl -n -e '$$_=`cat $$1` if /^\@(\S*)\@$$/ ; print' < grutatxt.src > grutatxt
	chmod 755 grutatxt

install:
	install -o root -g root -m 755 grutatxt $(PREFIX)/bin

tags:
	ctags --language-force=perl grutatxt.pl grutatxt.src

clean:
	-rm grutatxt *.tar.gz

dist: clean README.html
	cd ..; tar czvf grutatxt/grutatxt.tar.gz grutatxt/*

README.html: README
	./grutatxt -b < README > README.html
