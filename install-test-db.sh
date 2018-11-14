#!/bin/bash


export PGHOST=${PGHOST-localhost}
export PGDATA=${PGDATA-/var/lib/pgsql/data}
PGUSER=postgres
export PGUSER

if ! psql --help >/dev/null 2>&1 ; then
	echo "No psql command installed/found!" >&2
	exit 1
fi
if ! psql -c 'SELECT 1;' >/dev/null ; then
	echo "Unable to connect to Postgresql server on $PGHOST as user $PGUSER" >&2
	echo "Is the server running?" >&2
	exit 2
fi

postgisfiles=(/usr/share/pgsql/contrib/postgis-64.sql /usr/share/pgsql/contrib/postgis-2.0/topology.sql /usr/share/pgsql/contrib/postgis-2.0/rtpostgis.sql)
for pgfile in ${postgisfiles[*]} ; do
	if [ ! -r "$pgfile" ] ; then
		echo "$pgfile is unreadable. Is postgis installed?" >&2
		exit 3
	fi
done

sqlfiles=(db-create.sql role-create.sql db-rest.sql.bz2 postgisdbs.lst drop-all.sql)
paths=(`dirname $0` `dirname $0`/../db)
if [ -r "`dirname $0`/${sqlfiles[0]}" ] ; then
	fp="`dirname $0`"
fi 
if [ -r "`dirname $0`/../${sqlfiles[0]}" ] ; then
	d="`dirname $0`/.."
	fp="`cd $d ; pwd`"
fi 
if [ ! "$fp" ] ; then
	echo "Unable to find path for data files!" >&2
	exit 4
fi

for sqlf in ${sqlfiles[*]} ; do
	if [ ! -r "$fp/$sqlf" ] ; then
		echo "$fp/$sqlf is unreadable"
		exit 5
	fi
done

# Create database, ignore erros
psql -f "$fp/${sqlfiles[0]}"
# Create roles, ignore errors
psql -f "$fp/${sqlfiles[1]}"
# Take postgis into use, ignore errors
for pgdb in `cat ${sqlfiles[3]}` ; do
	for pgfile in ${postgisfiles[*]} ; do
		psql -f "$pgfile" $pgdb
	done	
done
# Create rest of the database, do not ignore errors
tmpf="`mktemp`db.sql"
bzcat < "$fp/${sqlfiles[2]}" > "$tmpf"
psql --set ON_ERROR_STOP=on -f "$tmpf"
r=$?
rm -f "$tmpf"
if [ "$r" != "0" ] ; then
	echo "Failed to populate database, please consider dropping everything and retrying" >&2
	exit 6
fi

# Done
exit 0
