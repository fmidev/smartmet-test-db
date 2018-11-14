#!/bin/bash

export PGHOST=${PGHOST-localhost}
export PGDATA=${PGDATA-/var/lib/pgsql/data}

if ! psql --help >/dev/null 2>&1 ; then
	echo "No psql command installed/found!" >&2
	exit 2
fi

# We only initialize local database: not remote servers
if [ "$PGHOST" = "localhost" ] ; then
	# Check prereqs
	if ! sudo -u postgres echo ; then
		echo "Unable to sudo to postgre user. Permissions ok and postgresql server installed?" >&2
		exit 3
	fi
	if ! command -v pg_ctl >/dev/null ; then 
		ecko "No pg_ctl command found. Is this really the server and/or has postgresql installed?" >&2
		exit 3
	fi
	if ! command -v initdb >/dev/null ; then 
		ecko "No initdb command found. Is this really the server and/or has postgresql installed?" >&2
		exit 3
	fi
	
	# Create database cluster if it does not exist
	if ! sudo -u postgres test -e "$PGDATA/PG_VERSION" ; then
		if ! sudo -u postgres initdb -E "UTF-8" -D "$PGDATA" ; then
			echo "$0: Initdb failed!" >&2
			exit 3
		fi
	fi

	# Start database cluster if it is not running
	if ! sudo -u postgres pg_ctl status -D "$PGDATA" >/dev/null ; then
		if ! sudo -u postgres pg_ctl -w -s -D "$PGDATA" start ; then
			echo "$0: Unable to start Postgresql server"
			exit 4
		fi
	fi
fi
