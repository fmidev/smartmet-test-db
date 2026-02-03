FROM postgis/postgis:15-3.5

# Set environment variables
ENV POSTGRES_DB=fminames
ENV POSTGRES_USER=fminames_user
ENV PGDATA=/var/lib/postgresql/data

# Remove the broken postgis init script from the base image
RUN rm -f /docker-entrypoint-initdb.d/10_postgis.sh /docker-entrypoint-initdb.d/10_update_postgis.sh || true

# Copy only the dumps and SQL files
COPY *.dump *.sql /docker-entrypoint-initdb.d/
COPY 20_restore-dumps.sh /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/*.sh

# Expose PostgreSQL port
EXPOSE 5432

# The init scripts will run automatically when container starts