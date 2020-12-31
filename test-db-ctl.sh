#! /bin/sh

export PGPORT=5444

if [ -z $1 ] ; then
    export PGDATA=$(pwd)/$(TOP)/tmp-db
else
    export PGDATA=$1
fi

if [ -x /usr/pgsql-12/bin/pg_ctl ]; then
  export PATH=/usr/pgsql-12/bin:$PATH
elif [ -x /usr/pgsql-9.5/bin/pg_ctl ]; then
  export PATH=/usr/pgsql-9.5/bin:$PATH
fi

shift

pg_ctl --pgdata=$PGDATA -o "-k /tmp -p $PGPORT" $*
