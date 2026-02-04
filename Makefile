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
mypgdir = $(localstatedir)/lib/smartmet-test-db/pgdata
objdir = obj

# How to install
INSTALL_PROG = install -p -m 775
INSTALL_DATA = install -p -m 664

# Databases in the test postgresql
DATABASES=authentication avi fminames gis icemap2storage_ro iot_obs

#.PHONY: test rpm

vpath %.dump dumps

# The rules
all: test-db-ok

test-db-ok: $(patsubst %, %.dump, $(DATABASES)) create-local-db.sh test-db-ctl.sh
	rm -rf test-database
	if ! ./create-local-db.sh test-database >test-database-create.log ; then \
	    cat test-database-create.log; \
	    false; \
	fi
	/usr/bin/date >$@

debug: all

release: all

clean:
	rm -f *~
	if [ -f test-database ] ; then ./test_db_ctl test_database stop -w; fi
	rm -rf test-database
	rm -f test-db-ok

rpm: clean $(SPEC).spec
	rm -f $(SPEC).tar.gz dist/* # Clean a possible leftover from previous attempt
	tar -czvf $(SPEC).tar.gz --transform "s,^,$(SPEC)/," *
	rpmbuild -tb $(SPEC).tar.gz
	rm -f $(SPEC).tar.gz

install:
	-./test_db_ctl stop
	mkdir -p $(mydatadir)/test/db $(mypgdir) $(prefix)/lib/systemd/system/
	cp -v *.sh *dump *sql $(mydatadir)/test/db
	cp -r test-database/* $(mypgdir)/
	/bin/echo /usr/pgsql-15/bin/postgres \"-D\" \"$(mypgdir\" >$(mypgdir)/postmaster.opts
	/bin/sed -i -e '/^max_connections\ =/s/100/500/' $(mypgdir)/postgresql.conf
	/bin/sed -i -e '/^port\ /d' $(mypgdir)/postgresql.conf
	/bin/echo "port = 5444" >>$(mypgdir)/postgresql.conf
	/bin/echo "listen_addresses '*'" >>$(mypgdir)/postgresql.conf
	/bin/echo "host    all             all              0.0.0.0/0                       md5" >>$(mypgdir)/pg_hba.conf
	/bin/echo "host    all             all              ::/0                            md5" >>$(mypgdir)/pg_hba.conf
	/bin/cp -p smartmet-test-db.service $(prefix)/lib/systemd/system/

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

test-installed: clean
	if ! $(mydatadir)/test/db/create-local-db.sh test-database >test-database-create.log 2>&1 ; then cat test-database-create.log; false; fi
	./test-local-db.sh test-database

testinstall:
	@echo "Testing installation file count"
	ls -l /usr/share/smartmet/test/db/
	test `ls /usr/share/smartmet/test/db/*.sql | wc -l` = "1"
	test `ls /usr/share/smartmet/test/db/*.dump | wc -l` = "6"
	test `ls /usr/share/smartmet/test/db/*.sh | wc -l` = "3"

.PHONY: test
