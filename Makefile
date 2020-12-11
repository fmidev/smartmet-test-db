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

# Databases in the test postgresql
DATABASES=authentication avi fminames gis icemap2storage_ro iot_obs

#.PHONY: test rpm

# The rules
all: 

debug: all

release: all

clean:
	rm -f *~

rpm: clean $(SPEC).spec
	rm -f $(SPEC).tar.gz dist/* # Clean a possible leftover from previous attempt
	tar -czvf $(SPEC).tar.gz --transform "s,^,$(SPEC)/," *
	rpmbuild -tb $(SPEC).tar.gz
	rm -f $(SPEC).tar.gz

install:
	mkdir -p $(mydatadir)/test/db
	cp -v *.pl *.sh *dump *sql $(mydatadir)/test/db

dumps:
	@echo Dumping globals to globals.sql
	@pg_dumpall -g -h smartmet-test -p 5444 -U postgres -f globals.sql
	@for db in $(DATABASES); do \
	  echo Dumping $$db to $$db.dump; \
	  pg_dump -h smartmet-test -p 5444 -U postgres -Fc -b -v -f $$db.dump $$db > /dev/null 2>&1; \
	done

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
	test `ls /usr/share/smartmet/test/db/*.sql | wc -l` = "1"
	test `ls /usr/share/smartmet/test/db/*.dump | wc -l` = "6"
	test `ls /usr/share/smartmet/test/db/*.sh | wc -l` = "4"
	test `ls /usr/share/smartmet/test/db/*.pl | wc -l` = "1"
