#! /bin/sh

if [ -z $1 ] ; then
    export PGDATA=$(pwd)/$(TOP)/tmp-db
else
    export PGDATA=$1
fi

export PGPORT=5444

shift

pg_ctl --pgdata=$PGDATA -o "-k /tmp -p $PGPORT" $*
