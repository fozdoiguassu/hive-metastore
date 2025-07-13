FROM apache/hive:4.0.1

LABEL org.opencontainers.image.source=https://github.com/fozdoiguassu/hive-metastore

ARG POSTGRES_CONNECTOR_VERSION=42.2.18

ENV SERVICE_NAME=metastore
ENV DATABASE_DRIVER=org.postgresql.Driver
ENV DATABASE_TYPE=postgres
ENV DATABASE_TYPE_JDBC=postgresql
ENV DATABASE_PORT=5432

USER root

RUN \
  echo "Install OS dependencies" && \
    build_deps="curl" && \
    apt-get update -y && \
    apt-get install -y $build_deps net-tools --no-install-recommends && \
  echo "Add S3a jars to the classpath using this hack" && \
    ln -s /opt/hadoop/share/hadoop/tools/lib/hadoop-aws* /opt/hadoop/share/hadoop/common/lib/ && \
    ln -s /opt/hadoop/share/hadoop/tools/lib/aws-java-sdk* /opt/hadoop/share/hadoop/common/lib/ && \
  echo "Download and install the database connector" && \
    curl -L https://jdbc.postgresql.org/download/postgresql-$POSTGRES_CONNECTOR_VERSION.jar --output /opt/postgresql-$POSTGRES_CONNECTOR_VERSION.jar && \
    ln -s /opt/postgresql-$POSTGRES_CONNECTOR_VERSION.jar /opt/hadoop/share/hadoop/common/lib/ && \
    ln -s /opt/postgresql-$POSTGRES_CONNECTOR_VERSION.jar /opt/hive/lib/ && \
  echo "Purge build artifacts" && \
    apt-get purge -y --auto-remove $build_deps && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG UID=1000
RUN chown -R hive:$UID /opt/tez && \
    chown -R hive:$UID /opt/hive && \
    chown -R hive:$UID /opt/hadoop && \
    chown -R hive:$UID /opt/hive/conf && \
    chown -R hive:$UID /opt/hive/data/warehouse && \
    chown -R hive:$UID /home/hive/.beeline

USER hive
