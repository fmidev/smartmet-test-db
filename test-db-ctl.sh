#! /bin/sh

export PGPORT=5432

if [ -z $1 ] ; then
    export PGDATA=$(realpath $(TOP)/tmp-db)
else
    export PGDATA=$(realpath $1)
    if ! echo $PGDATA | grep -q ^/ ; then PGDATA=$(pwd)/$PGDATA; fi
fi

if [ -x /usr/pgsql-15/bin/pg_ctl ]; then
  export PATH=/usr/pgsql-15/bin:$PATH
fi

shift

pg_ctl --pgdata=$PGDATA -o "-h \"\" -p $PGPORT -k $PGDATA" $*
