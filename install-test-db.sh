#!/bin/bash

export PGHOST=${PGHOST-localhost}
export PGPORT=${PGPORT-5444}
export PGDATA=${PGDATA-/var/lib/pgsql/9.5/data}
PGUSER=postgres
export PGUSER

PSQL=/usr/pgsql-9.5/bin/psql

if ! $PSQL --help >/dev/null 2>&1 ; then
	echo "No psql command installed/found!" >&2
	exit 1
fi
if ! $PSQL -c 'SELECT 1;' >/dev/null ; then
	echo "Unable to connect to Postgresql server on $PGHOST as user $PGUSER" >&2
	echo "Is the server running?" >&2
	exit 2
fi

postgisfiles=(/usr/pgsql-9.5/share/contrib/postgis-2.4/postgis.sql /usr/pgsql-9.5/share/contrib/postgis-2.4/topology.sql /usr/pgsql-9.5/share/contrib/postgis-2.4/rtpostgis.sql)
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

# Check CLI paramaters
case $1 in
	drop*)
		$PSQL --set ON_ERROR_STOP=on -f "$fp/${sqlfiles[4]}"
		if [ "$?" != "0" ] ; then
			echo "Drop script $fp/${sqlfiles[4]} failed to work - should work always."
			exit 5
		fi
		# Only drop, don't continue
		if [ "$1" = "droponly" ] ; then
			exit 0
		fi
		;;
esac

# Create database, ignore erros
$PSQL -f "$fp/${sqlfiles[0]}"
# Create roles, ignore errors
$PSQL -f "$fp/${sqlfiles[1]}"
# Take postgis into use, ignore errors
tmpf="`mktemp`"
for pgdb in `cat "$fp/${sqlfiles[3]}"` ; do
	for pgfile in ${postgisfiles[*]} ; do
		$PSQL -f "$pgfile" $pgdb && echo "$pgdb: $pgfile" >> $tmpf
	done
done
if [ `wc -l < $tmpf` -lt ${#postgisfiles[@]} ] ; then
	echo "Failed to add Postgis extensions to any database!"
	rm -f "$tmpf"
	exit 10
fi
echo "Postgis added:"
cat "$tmpf"
rm -f "$tmpf"

# Create rest of the database, do not ignore errors
tmpf="`mktemp`db.sql"
bzcat < "$fp/${sqlfiles[2]}" > "$tmpf"
$PSQL --set ON_ERROR_STOP=on -f "$tmpf"
r=$?
rm -f "$tmpf"
if [ "$r" != "0" ] ; then
	echo "Failed to populate database, please consider dropping everything and retrying" >&2
	exit 6
fi

# Done
exit 0
