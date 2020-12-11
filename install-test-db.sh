#!/bin/bash -x

export PGHOST=${PGHOST-localhost}
export PGPORT=${PGPORT-5444}
export PGUSER=postgres

# Establish PGDG paths and the postgis files to be executed when initializing the db

if [ -x /usr/pgsql-12/bin/pg_ctl ]; then
  export PATH=$PATH:/usr/pgsql-12/bin
  pgpath=/usr/pgsql-12/share/contrib/postgis-3.1/
  postgisfiles=($pgpath/postgis.sql $pgpath/topology.sql $pgpath/rtpostgis.sql)
elif [ -x /usr/pgsql-9.5/bin/pg_ctl ]; then
  export PATH=$PATH:/usr/pgsql-9.5/bin
  pgpath=/usr/pgsql-9.5/share/contrib/postgis-2.4/
  postgisfiles=($pgpath/postgis.sql $pgpath/topology.sql $pgpath/rtpostgis.sql)
else
  postgisfiles=(/usr/share/pgsql/contrib/postgis-64.sql /usr/share/pgsql/contrib/postgis-2.0/topology.sql /usr/share/pgsql/contrib/postgis-2.0/rtpostgis.sql)
fi

# Verify required commands and scripts exist

if ! psql --help >/dev/null 2>&1 ; then
	echo "No psql command installed/found!" >&2
	exit 1
fi
if ! psql -c 'SELECT 1;' >/dev/null ; then
	echo "Unable to connect to Postgresql server on $PGHOST as user $PGUSER" >&2
	echo "Is the server running?" >&2
	exit 2
fi

for pgfile in ${postgisfiles[*]} ; do
	if [ ! -r "$pgfile" ] ; then
		echo "$pgfile is unreadable. Is postgis installed?" >&2
		exit 3
	fi
done

# Check command line arguments: stop, drop, droponly

case $1 in
    drop*)
	echo Not dropping anything - test stub
	if [ "$1" =0 "dropoonly" ]; then
	    exit 0;
	fi
	;;
    stop)
	echo Not stopping anything - test stub
	exit 0
	;;
esac

# Normal execution imports data into the database

psql -f globals.sql

# Create databases
ok=true
for dump in *.dump; do
  db=$(basename $dump .dump)
  echo Importing $dump
  perl postgis_restore.pl "$dump" | psql $db || ok=false
  for pgfile in $postgisfiles; do
      psql -f "$pgfile" $db || ok=false
  done
done

# Exit value:
$ok

