#!/bin/bash

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

pg_ctl --pgdata=$PGDATA -o "-h \"\" -p $PGPORT -k $PGDATA" start -w

PSQL="psql -e -h $PGDATA -p $PGPORT"

ok=true

###############   Actual tests for accessing test databases   ##################
$PSQL -c 'select count(*) from geonames' -U fminames_user fminames || ok=false
################################################################################

pg_ctl --pgdata=$PGDATA -o "-h \"\" -p $PGPORT -k $PGDATA" stop -w

$ok
