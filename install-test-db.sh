#!/bin/bash -x

export PGHOST=${PGHOST-localhost}
export PGPORT=${PGPORT-5444}
export PGUSER=postgres
export PGDATA=${PGDATA-/var/lib/pgsql/data}

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
    stop)
	echo Stopping the database
	pg_ctl -D "$PGDATA" -p $PGPORT stop
	exit 0
	;;
esac

# Normal execution imports data into the database

psql -f /usr/share/smartmet/test/db/globals.sql

# Create databases
cd /tmp

ok=true
for dump in /usr/share/smartmet/test/db/*.dump; do
  db=$(basename $dump .dump)
  echo Creating $db
  createdb $db
  echo Creating postgis extension
  psql -c "CREATE EXTENSION postgis;"
  echo Importing $dump
  for pgfile in $postgisfiles; do
      psql -f "$pgfile" $db || ok=false
  done
  perl /usr/share/smartmet/test/db/postgis_restore.pl "$dump" | psql $db 2>/dev/null || ok=false
done

# Exit value:
$ok

