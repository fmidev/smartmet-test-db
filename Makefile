SUBNAME = test-db
SPEC = smartmet-$(SUBNAME)

# Installation directories
ifeq ($(origin PREFIX), undefined)
  PREFIX = /usr
else
  PREFIX = $(PREFIX)
endif
datadir = $(PREFIX)/share
mydatadir = $(datadir)/smartmet
objdir = obj

# How to install
INSTALL_PROG = install -p -m 775
INSTALL_DATA = install -p -m 664

#.PHONY: test rpm

# The rules
all: drop-all.sql

debug: all
release: all
profile: all

clean:
	rm -f *~ $(SUBNAME)/*~ db-rest.sql.bz2 db-create.sql role-create.sql drop-all.sql postgisdbs.lst

install:
	@mkdir -p $(mydatadir)/test/db
	cp -v *.sql* postgisdbs.lst $(mydatadir)/test/db

db-rest.sql.bz2 db-create.sql role-create.sql drop-all.sql postgisdbs.lst: db-dump.bz2 database-script-creator.pl Makefile
	bzcat db-dump.bz2 > tmp3
	./database-script-creator.pl db-create.sql role-create.sql tmp postgisdbs.lst < tmp3 > tmp2
	rm tmp3
	bzip2 -c9 < tmp2 > db-rest.sql.bz2
	sort < tmp > tmp2
	rm tmp
	mv tmp2 drop-all.sql

rpm: clean $(SPEC).spec
	rm -f $(SPEC).tar.gz # Clean a possible leftover from previous attempt
	tar -czvf $(SPEC).tar.gz --transform "s,^,$(SPEC)/," *
	rpmbuild -ta $(SPEC).tar.gz
	rm -f $(SPEC).tar.gz

# Test:
# - warn about data being destroyed
# - init%start database if needed (if PG_HOST is localhost and postgresql is not running)
# - check database connectivity
# - clean databse of test data(without checking errors)
# - insert test data(with error checking)
# - check something(?)
# - clean database of test data(with error checking)
test:
	test ! -d /usr/share/smartmet/test/db || rpm -ql smartmet-test-db
