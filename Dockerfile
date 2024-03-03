FROM openjdk:16-slim

# Lifted from: https://github.com/joshuarobinson/presto-on-k8s/blob/1c91f0b97c3b7b58bdcdec5ad6697b42e50d74c7/hive_metastore/Dockerfile

# see https://hadoop.apache.org/releases.html
ARG HADOOP_VERSION=3.3.6
# see https://downloads.apache.org/hive/
ARG HIVE_METASTORE_VERSION=3.1.3
# see https://jdbc.postgresql.org/download.html#current
ARG POSTGRES_CONNECTOR_VERSION=42.7.2

# Set necessary environment variables.
ENV HADOOP_HOME="/opt/hadoop"
ENV PATH="/opt/spark/bin:/opt/hadoop/bin:${PATH}"
ENV DATABASE_DRIVER=org.postgresql.Driver
ENV DATABASE_TYPE=postgres
ENV DATABASE_TYPE_JDBC=postgresql
ENV DATABASE_PORT=5432

WORKDIR /app
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install --no-install-recommends -y apt-transport-https ca-certificates curl gnupg \
    && curl -sLf --retry 3 --tlsv1.2 --proto "=https" 'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" | tee /etc/apt/sources.list.d/doppler-cli.list \
    && apt-get update \
    && apt-get -y --no-install-recommends install doppler \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# hadolint ignore=DL3008
RUN echo "Install OS dependencies" && \
    build_deps="curl" && \
    apt-get update -y && \
    apt-get install -y $build_deps net-tools --no-install-recommends && \
  echo "Download and extract the Hadoop binary package" && \
    curl https://archive.apache.org/dist/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
    | tar xvz -C /opt/ && \
    ln -s /opt/hadoop-${HADOOP_VERSION} /opt/hadoop && \
    rm -r /opt/hadoop/share/doc && \
  echo "Add S3a jars to the classpath using this hack" && \
    ln -s /opt/hadoop/share/hadoop/tools/lib/hadoop-aws* /opt/hadoop/share/hadoop/common/lib/ && \
    ln -s /opt/hadoop/share/hadoop/tools/lib/aws-java-sdk* /opt/hadoop/share/hadoop/common/lib/ && \
  echo "Download and install the standalone metastore binary" && \
    curl https://repo1.maven.org/maven2/org/apache/hive/hive-standalone-metastore/${HIVE_METASTORE_VERSION}/hive-standalone-metastore-${HIVE_METASTORE_VERSION}-bin.tar.gz \
    | tar xvz -C /opt/ && \
    ln -s /opt/apache-hive-metastore-${HIVE_METASTORE_VERSION}-bin /opt/hive-metastore && \
  echo "Fix 'java.lang.NoSuchMethodError: com.google.common.base.Preconditions.checkArgument'" && \
  echo "Keep this until this lands: https://issues.apache.org/jira/browse/HIVE-22915" && \
    rm /opt/apache-hive-metastore-${HIVE_METASTORE_VERSION}-bin/lib/guava-19.0.jar && \
    cp /opt/hadoop-${HADOOP_VERSION}/share/hadoop/hdfs/lib/guava-27.0-jre.jar /opt/apache-hive-metastore-${HIVE_METASTORE_VERSION}-bin/lib/ && \
  echo "Download and install the database connector" && \
    curl -L https://jdbc.postgresql.org/download/postgresql-${POSTGRES_CONNECTOR_VERSION}.jar --output /opt/postgresql-${POSTGRES_CONNECTOR_VERSION}.jar && \
    ln -s /opt/postgresql-${POSTGRES_CONNECTOR_VERSION}.jar /opt/hadoop/share/hadoop/common/lib/ && \
    ln -s /opt/postgresql-${POSTGRES_CONNECTOR_VERSION}.jar /opt/hive-metastore/lib/ && \
  echo "Purge build artifacts" && \
    apt-get purge -y --auto-remove $build_deps && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY run.sh run.sh

ENTRYPOINT ["doppler", "run", "--"]

CMD [ "./run.sh" ]
HEALTHCHECK --interval=5m CMD [ "sh", "-c", "netstat -ln | grep 9083" ]
