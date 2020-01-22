ARG cassandra_version
FROM cassandra:3.11.5


ADD jmx_prometheus_javaagent-0.12.0.jar /usr/share/cassandra/lib/
ADD jmx_exporter.yml /etc/cassandra/jmx_exporter.yml

RUN echo "-javaagent:/usr/share/cassandra/lib/jmx_prometheus_javaagent-0.12.0.jar=7070:/etc/cassandra/jmx_exporter.yml" >> /etc/cassandra/jvm.options
