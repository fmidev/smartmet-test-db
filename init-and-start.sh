#!/bin/bash -x

export PGHOST=${PGHOST-localhost}
export PGDATA=${PGDATA-/var/lib/pgsql/data}
export PGPORT=${PGPORT-5444}

# Establish PGDG paths

if [ -x /usr/pgsql-12/bin/pg_ctl ]; then
  export PATH=$PATH:/usr/pgsql-12/bin
elif [ -x /usr/pgsql-9.5/bin/pg_ctl ]; then
  export PATH=$PATH:/usr/pgsql-9.5/bin
fi

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
		echo "No pg_ctl command found. Is this really the server and/or has postgresql installed?" >&2
		exit 3
	fi
	if ! command -v initdb >/dev/null ; then 
		echo "No initdb command found. Is this really the server and/or has postgresql installed?" >&2
		exit 3
	fi
	
	# Create database cluster if it does not exist
	if ! sudo -u postgres test -e "$PGDATA/PG_VERSION" ; then
		if ! sudo -u postgres initdb -E "UTF-8" -D "$PGDATA" ; then
			echo "$0: initdb failed!" >&2
			exit 3
		fi
	fi

	# Start database cluster if it is not running
	if ! sudo -u postgres pg_ctl status -D "$PGDATA" -o "-p $PGPORT" >/dev/null ; then
		if ! sudo -u postgres pg_ctl -w -s -D "$PGDATA" -o "-F -p $PGPORT" start ; then
			echo "$0: Unable to start Postgresql server"
			exit 4
		fi
	fi

	# Stop instead
	if [ "$1" = "stop" ] ; then
		if ! sudo -u postgres pg_ctl -w -s -D "$PGDATA" -o "-p $PGPORT" stop ; then
			echo "$0: Unable to stop Postgresql server"
			exit 5
		fi
	fi
fi
