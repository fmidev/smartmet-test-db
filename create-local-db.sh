#! /bin/sh
#
# create-local-db.sh [ tmp-db [ [ pg_restore | collation_C ] [ dumpfile dumpfile ... ] ]

set -x

if [ -z $1 ] ; then
    export PGDATA=$(realpath tmp-db)
else
    mkdir -p $1
    export PGDATA=$(realpath $1)
    if ! echo $PGDATA | grep -q ^/ ; then PGDATA=$(pwd)/$PGDATA; fi
fi

# If pg_restore is given, use pg_restore instead of postgis_restore.pl.
# If collation_C is given, use C collation instead of en_US.UTF-8.
# Loading only given dump files (e.g. avi.dump] if any are given.
#
# For example avi database does not need any special (postgis_restore.pl) handling,
# and if collation is set to en_US.UTF-8, e.g. some avi tests fail due to data
# ordering changes.

pgdata=$1

use_pg_restore=false
use_collation_C=false

for arg in 2 2; do
    if [ "$2" = "pg_restore" -o "$2" = "collation_C" ]; then
        eval "use_$2=true"; shift
    fi
done

dumps=()
if [ ! -z "$2" ] ; then
    shift
    dumps=($*)
fi

set $pgdata

# Establish PGDG paths

export PGPORT=5444
prefix=$(dirname $0)

test_db_input=
if [ "$prefix" == "." ] && [ -f globals.sql ] ; then
    test_db_input="."
    prefix=$(pwd)
else
    case $prefix in
	/*)
	    ;;
	*)
	    prefix=/usr/share/smartmet/test/db
	    ;;
    esac
fi

INITDB="initdb --pgdata $PGDATA -U postgres"
POSTGRES_PARAM="-k $PGDATA -p $PGPORT -h \"\" -F"
DBCONN="-h $PGDATA -p $PGPORT -U postgres"
PSQL="psql $DBCONN"
PSQL_NOERR="$PSQL --set ON_ERROR_STOP=on"

if [ -x /usr/pgsql-13/bin/pg_ctl ]; then
  export PATH=/usr/pgsql-13/bin:$PATH
  if [ -d /usr/pgsql-13/share/contrib/postgis-3.2/ ] ; then
      pgpath=/usr/pgsql-13/share/contrib/postgis-3.2/
  else
      pgpath=/usr/pgsql-13/share/contrib/postgis-3.1/
  fi
  postgisfiles=($pgpath/postgis.sql $pgpath/topology.sql $pgpath/rtpostgis.sql $pgpath/spatial_ref_sys.sql )
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

# Do NOT initialize with the C-locale or collations are not installed
if [ "$use_collation_C" == false ]; then
    export LC_ALL="en_US.UTF-8"
else
    export LC_ALL="C"
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
$PSQL -f $prefix/globals.sql

echo Creating postgis extensions
$PSQL -c "CREATE EXTENSION postgis;"
$PSQL -c "CREATE EXTENSION postgis_raster;"
$PSQL -c "CREATE EXTENSION postgis_topology;"

# Create databases. We need to be able to create manifest files from the dumps, hence we use /tmp
mkdir -p /tmp/smartmet-test-db
cd /tmp/smartmet-test-db
cp -v $prefix/* .

# Check if dump file name is included in the list of dump file names given (if any)
excludeDump() {
    local dump="$1"; shift; local dumps=("$@")

    if [ ${#dumps[@]} -eq 0 ]; then return 1; fi

    for d in "${dumps[@]}"; do
        if [ $d = $dump ]; then return 1; fi
    done

    return 0
}

ok=true
for dump in *.dump; do
  if excludeDump $dump ${dumps[@]}; then
      continue
  fi

  db=$(basename $dump .dump)

  echo Creating $db
  $PSQL -c "CREATE DATABASE $db;"

  echo Importing $dump
  for pgfile in ${postgisfiles[*]}; do
      $PSQL -f "$pgfile" $db || ok=false
  done

  if [ $use_pg_restore = true ]; then
      pg_restore -Fc $DBCONN -d $db "$dump" || ok=false
  else
      perl $postgisrestore -s public "$dump" | $PSQL $db || ok=false
  fi
done

# Exit value:
if ! $ok ; then
    echo "Failed to populate database, please consider dropping everything and retrying" 1>&2
    echo "See earlier messages for more information" 1>&2
fi

$ok
