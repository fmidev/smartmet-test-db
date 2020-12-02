#! /bin/sh

set -x

if [ -z $1 ] ; then
    export PGDATA=$(pwd)/tmp-db
else
    export PGDATA=$1
fi

export PGPORT=15444
prefix=$(dirname $0)

INITDB="initdb --pgdata $PGDATA -U postgres"
POSTGRES_PARAM="-k /tmp -p $PGPORT -F"
PSQL="psql -p $PGPORT -h 127.0.0.1 -U postgres"
PSQL_NOERR="$PSQL --set ON_ERROR_STOP=on"

postgisfiles=(\
            /usr/share/pgsql/contrib/postgis-64.sql \
            /usr/share/pgsql/contrib/postgis-2.0/topology.sql \
            /usr/share/pgsql/contrib/postgis-2.0/rtpostgis.sql)

sqlfiles=(db-create.sql role-create.sql db-rest.sql.bz2 postgisdbs.lst drop-all.sql)

stop_database() {
    pg_ctl --pgdata=$PGDATA -o "-k /tmp -p $PGPORT" stop
}

postgisfiles_missing=
for pgfile in ${postgisfiles[*]}; do test -f $pgfile || postgisfiles_missing="$postgisfiles_missing $pgfile"; done
if ! [ -z "$postgisfiles_missing" ] ; then
    echo "Files missing:\n   $postgisfiles_missing\n"
    echo "Is postgis-2.0 installed"
    exit 1
fi

if ! psql --help >/dev/null 2>&1 ; then
    echo "No psql command found"
    exit 1
fi

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

sqlfiles_missing=
for sqlfile in ${sqlfiles[*]}; do test -f $prefix/$sqlfile || sqlfiles_missing="$sqlfiles_missing $sqlfile"; done
if ! [ -z "$sqlfiles_missing" ] ; then
    echo "Data files not found:\n $sqlfiles_missing\n"
    exit 1
fi

rm -rf tmp-db
if ! $INITDB ; then
    echo "Failed to create PostgreSQL database cluster"
    exit 1
fi

cleanup() {
    echo "Stopping Postgresql server..."
    pg_ctl --pgdata=$PGDATA -o "-k /tmp -p $PGPORT" stop
}

if pg_ctl --pgdata=$PGDATA -o "-k /tmp -p $PGPORT -F" start ; then
    trap cleanup 0
    trap cleanup 2
    trap cleanup 15
else
    echo "Failed to start PostgreSQL server"
    exit 1
fi

sleep 3

if ! $PSQL -c 'SELECT 1;' >/dev/null 2>&1 ; then
    echo "Unable top connect to PostgreSQL server"
    exit 1
fi

# Create database, ignore erros
$PSQL -f ${prefix}/${sqlfiles[0]}

# Create roles, ignore errors
$PSQL -f ${prefix}/${sqlfiles[1]}

# Take postgis into use, ignore errors
tmpf="`mktemp`"
for pgdb in $(cat ${prefix}/${sqlfiles[3]}) ; do
	for pgfile in ${postgisfiles[*]} ; do
	        case "$pgfile" in *.bzip2) bzip2 -cd $pgfile ;; *) cat $pgfile ;; esac |\
		$PSQL $pgdb && echo "$pgdb: $pgfile" >> $tmpf
	done
done
if [ $(wc -l < $tmpf) -lt ${#postgisfiles[@]} ] ; then
	echo "Failed to add Postgis extensions to any database!"
	rm -f "$tmpf"
	exit 10
fi
echo "Postgis added:"
cat "$tmpf"
rm -f "$tmpf"

# Create rest of the database, do not ignore errors
tmpf="`mktemp`db.sql"
if ! bzip2 -cd ${prefix}/${sqlfiles[2]} | $PSQL --set ON_ERROR_STOP=on ; then
    echo "Failed to populate database, please consider dropping everything and retrying" >&2
    exit 6
fi
