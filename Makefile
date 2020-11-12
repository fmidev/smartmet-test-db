SUBNAME = test-db
SPEC = smartmet-$(SUBNAME)

# Installation directories
ifeq ($(origin PREFIX), undefined)
  PREFIX = /usr
else
  PREFIX = $(PREFIX)
endif
prefix = $(PREFIX)
datadir = $(PREFIX)/share
mydatadir = $(datadir)/smartmet
localstatedir = $(datadir)/var
mypgdir = $(localstatedir)/lib/$(SPEC)
objdir = obj

# How to install
INSTALL_PROG = install -p -m 775
INSTALL_DATA = install -p -m 664

#.PHONY: test rpm

# The rules
all: db-rest.sql.bz2 s-local-db

debug: all
release: all
profile: all

clean:
	rm -f *~ $(SUBNAME)/*~ db-rest.sql.bz2 db-create.sql role-create.sql drop-all.sql postgisdbs.lst db-dump db-rest.sql
	rm -rf tmp pgdata

s-local-db:
	./create-local-db.sh
	touch s-local-db

install:
	mkdir -p $(mydatadir)/test/db
	cp -v db-create.sql role-create.sql drop-all.sql postgisdbs.lst *.sql.bz2 $(mydatadir)/test/db
	cp -v init-and-start.sh install-test-db.sh $(mydatadir)/test/db
	mkdir -p $(mypgdir)
	( tar cv pgdata ) | ( cd $(mypgdir) && tar x )
	mkdir -p $(prefix)/lib/systemd/system
	cp -p smartmet-test-db.service $(prefix)/lib/systemd/system/

db-dump: db-dump.bz2
	bzcat db-dump.bz2 > db-dump

db-rest.sql.bz2: db-rest.sql
	bzip2 -c9 < db-rest.sql > db-rest.sql.bz2

db-rest.sql db-create.sql role-create.sql drop-all.sql postgisdbs.lst: db-dump database-script-creator.pl Makefile
	./database-script-creator.pl db-create.sql role-create.sql tmp3 postgisdbs.lst < db-dump > tmp2
	sort < tmp3 > drop-all.sql
	rm -f tmp3
	mv tmp2 db-rest.sql

rpm: clean $(SPEC).spec
	rm -f $(SPEC).tar.gz dist/* # Clean a possible leftover from previous attempt
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
pginit =  $(shell ( ( test "`echo $$CIRCLE_JOB | cut -f 1 -d -`" = "test" && echo $(mydatadir)/test/db/init-and-start.sh ) || echo ./init-and-start.sh ))
dbinst =  $(shell ( ( test "`echo $$CIRCLE_JOB | cut -f 1 -d -`" = "test" && echo $(mydatadir)/test/db/install-test-db.sh ) || echo ./install-test-db.sh ))

test:
	echo "CI=$$CI"
	@test "$$CI" = "true" || ( \
		echo "Running make test outside of CI will destroy local(or PGHOST) database contents!" ; \
		echo "If you are sure, set environment CI=true" ; false )
	test ! -d /usr/share/smartmet/test/db || make testinstall
	PGPORT=12543 $(pginit) # Test init
	ps ax | grep -q 'postgres -D [/]*' # Check postgres is running
	PGPORT=12543 $(pginit) stop # Test reinit and stop after that
	PGPORT=12543 $(pginit) # Should actually just start
	PGPORT=12543 $(dbinst) drop # Install, possibly dropping previous
	PGPORT=12543 $(dbinst) droponly # Remove test data
	PGPORT=12543 $(pginit) stop # Stop db
	if ( ps ax | grep -q 'postgres -D [/]*' ) ; then true ; fi # Check postgres is not running
	@echo All tests passed.

testinstall:
	@echo "Testing installation file count"
	ls -l /usr/share/smartmet/test/db/
	test `ls /usr/share/smartmet/test/db/*.sql* | wc -l` = "4"
	test `ls /usr/share/smartmet/test/db/*.sh | wc -l` = "2"
