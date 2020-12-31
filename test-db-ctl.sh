#! /bin/sh

export PGPORT=5444

if [ -z $1 ] ; then
    export PGDATA=$(pwd)/$(TOP)/tmp-db
else
    export PGDATA=$1
fi

if [ -x /usr/pgsql-12/bin/pg_ctl ]; then
  export PATH=$PATH:/usr/pgsql-12/bin
elif [ -x /usr/pgsql-9.5/bin/pg_ctl ]; then
  export PATH=$PATH:/usr/pgsql-9.5/bin
fi

shift

pg_ctl --pgdata=$PGDATA -o "-k /tmp -p $PGPORT" $*
