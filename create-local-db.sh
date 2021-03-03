#! /bin/sh

set -x

if [ -z $1 ] ; then
    export PGDATA=$(realpath tmp-db)
else
    mkdir -p $1
    export PGDATA=$(realpath $1)
    if ! echo $PGDATA | grep -q ^/ ; then PGDATA=$(pwd)/$PGDATA; fi
fi

# Establish PGDG paths

if [ -x /usr/pgsql-12/bin/pg_ctl ]; then
  export PATH=$PATH:/usr/pgsql-12/bin
elif [ -x /usr/pgsql-9.5/bin/pg_ctl ]; then
  export PATH=$PATH:/usr/pgsql-9.5/bin
fi

export PGPORT=5444
prefix=$(dirname $0)

INITDB="initdb --pgdata $PGDATA -U postgres"
POSTGRES_PARAM="-k $PGDATA -p $PGPORT -h \"\" -F"
PSQL="psql -h $PGDATA -p $PGPORT -U postgres"
PSQL_NOERR="$PSQL --set ON_ERROR_STOP=on"

if [ -x /usr/pgsql-12/bin/pg_ctl ]; then
  export PATH=/usr/pgsql-12/bin:$PATH
  pgpath=/usr/pgsql-12/share/contrib/postgis-3.1/
  postgisfiles=($pgpath/postgis.sql $pgpath/topology.sql $pgpath/rtpostgis.sql)
  postgisrestore=$pgpath/postgis_restore.pl
elif [ -x /usr/pgsql-9.5/bin/pg_ctl ]; then
  export PATH=/usr/pgsql-9.5/bin:$PATH
  pgpath=/usr/pgsql-9.5/share/contrib/postgis-3.0/
  postgisfiles=($pgpath/postgis.sql $pgpath/topology.sql $pgpath/rtpostgis.sql)
  postgisrestore=$pgpath/postgis_restore.pl
else
  postgisfiles=(/usr/share/pgsql/contrib/postgis-64.sql /usr/share/pgsql/contrib/postgis-2.0/topology.sql /usr/share/pgsql/contrib/postgis-2.0/rtpostgis.sql)
  postgisrestore=/usr/share/postgis/postgis_restore.pl
fi

postgisfiles_missing=
for pgfile in ${postgisfiles[*]}; do test -f $pgfile || postgisfiles_missing="$postgisfiles_missing $pgfile"; done
if ! [ -z "$postgisfiles_missing" ] ; then
    echo "Files missing:\n   $postgisfiles_missing\n"
    echo "Is postgis installed"
    exit 1
fi

if ! psql --help >/dev/null 2>&1 ; then
    echo "No psql command found"
    exit 1
fi

psql --version

# Check whether server is already running. Stop it if necessary
if [ -f $PGDATA/postmaster.pid ] ; then
    pid=$(head -1 $PGDATA/postmaster.pid)
    echo Seems that server is running. Try to stop it
    stop_database >/dev/null 2>&1
    if ! [ -z "$pid" ] ; then
        if readlink "/proc/$pid/exe" 2>/dev/null | grep -s postgres; then
            kill $pid;
            sleep 3
        fi
    fi
fi

rm -rf tmp-db
if ! $INITDB ; then
    echo "Failed to create PostgreSQL database cluster"
    exit 1
fi

stop_database() {
    pg_ctl --pgdata=$PGDATA -o "-l "" -k $PGDATA -h \"\"" stop -w
}

cleanup() {
    echo "Stopping Postgresql server..."
    pg_ctl --pgdata=$PGDATA -o "-k $PGDATA -h \"\"" stop -w
}

if pg_ctl --pgdata=$PGDATA -o "-k $PGDATA -h \"\" -F" start -w ; then
    trap cleanup 0
    trap cleanup 2
    trap cleanup 15
else
    echo "Failed to start PostgreSQL server"
    exit 1
fi

sleep 3

if ! $PSQL -c 'SELECT 1;' >/dev/null 2>&1 ; then
    echo "Unable to connect to PostgreSQL server"
    exit 1
fi

# Normal execution imports data into the database
$PSQL -f /usr/share/smartmet/test/db/globals.sql

echo Creating postgis extensions
$PSQL -c "CREATE EXTENSION postgis;"
$PSQL -c "CREATE EXTENSION postgis_raster;"
$PSQL -c "CREATE EXTENSION postgis_topology;"

# Create databases. We need to be able to create manifest files from the dumps, hence we use /tmp
mkdir -p /tmp/smartmet-test-db
cd /tmp/smartmet-test-db
cp -v /usr/share/smartmet/test/db/* .

ok=true
for dump in *.dump; do
  db=$(basename $dump .dump)
  echo Creating $db
  $PSQL -c "CREATE DATABASE $db;"
  echo Importing $dump
  for pgfile in $postgisfiles; do
      $PSQL -f "$pgfile" $db 2>/dev/null || ok=false
  done
  perl ./postgis_restore.pl "$dump" | $PSQL $db 2>/dev/null || ok=false
done

# Exit value:
if ! $ok ; then
    echo "Failed to populate database, please consider dropping everything and retrying" 1>&2
    echo "See earlier messages for more information" 1>&2
fi

$ok
