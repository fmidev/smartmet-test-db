#!/bin/bash
set -e

# PostGIS extensions are already available in the postgis/postgis image
# Just enable them in the default database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_raster;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
EOSQL

# Restore each dump file
for dump in /docker-entrypoint-initdb.d/*.dump; do
    if [ -f "$dump" ]; then
        db=$(basename "$dump" .dump)
        
        # If the dump name matches POSTGRES_DB, restore to the existing default database
        if [ "$db" = "$POSTGRES_DB" ]; then
            echo "Restoring $dump into existing database $POSTGRES_DB"
            # Restore everything with full output to see what's happening
            pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
                --no-owner --no-privileges --verbose \
                "$dump" 2>&1 | tee /tmp/restore_${db}_full.log || true
            echo "Completed restoring $db"
            continue
        fi
        
        # For other databases, check if they exist
        if psql -U "$POSTGRES_USER" -d postgres -lqt | cut -d \| -f 1 | grep -qw "$db"; then
            echo "Database $db already exists, skipping creation but will check for data"
        else
            echo "Creating database: $db"
            psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
                CREATE DATABASE "$db";
EOSQL
        fi
        
        echo "Enabling PostGIS extensions in $db"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<-EOSQL
            CREATE EXTENSION IF NOT EXISTS postgis;
            CREATE EXTENSION IF NOT EXISTS postgis_raster;
            CREATE EXTENSION IF NOT EXISTS postgis_topology;
EOSQL
        
        echo "Restoring dump: $dump into $db"
        pg_restore -U "$POSTGRES_USER" -d "$db" \
            --no-owner --no-privileges \
            "$dump" 2>&1 | grep -E -v "(already exists|does not exist|postgis-2.3)" | grep -v "ERROR" || true
    fi
done

echo "Database initialization complete"