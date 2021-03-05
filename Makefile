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
	if [ -f test-database ] ; then ./test_db_ctl test_database stop -w; fi
	rm -rf test-database

rpm: clean $(SPEC).spec
	rm -f $(SPEC).tar.gz dist/* # Clean a possible leftover from previous attempt
	tar -czvf $(SPEC).tar.gz --transform "s,^,$(SPEC)/," *
	rpmbuild -tb $(SPEC).tar.gz
	rm -f $(SPEC).tar.gz

install:
	mkdir -p $(mydatadir)/test/db
	cp -v *.sh *dump *sql *.pl $(mydatadir)/test/db

dumps:
	@echo Dumping globals to globals.sql
	@pg_dumpall -g -h smartmet-test -p 5444 -U postgres -f globals.sql
	@for db in $(DATABASES); do \
	  echo Dumping $$db to $$db.dump; \
	  pg_dump -h smartmet-test -p 5444 -U postgres -Fc -b -v -f $$db.dump $$db > /dev/null 2>&1; \
	done

test:	clean
	if ! ./create-local-db.sh test-database >test-database-create.log 2>&1 ; then cat test-database-create.log; false; fi
	./test-local-db.sh test-database

testinstall:
	@echo "Testing installation file count"
	ls -l /usr/share/smartmet/test/db/
	test `ls /usr/share/smartmet/test/db/*.sql | wc -l` = "1"
	test `ls /usr/share/smartmet/test/db/*.dump | wc -l` = "6"
	test `ls /usr/share/smartmet/test/db/*.sh | wc -l` = "3"

.PHONY: test
