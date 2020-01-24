cassandra_version := 3.11.5
jmx_exporter_version := 0.12.0

image := gcr.io/pm-registry/cassandra:$(cassandra_version)

.DEFAULT_GOAL := docker
.PHONY: docker

agent_jar := jmx_prometheus_javaagent-$(jmx_exporter_version).jar

# Docker doesn't produce anything on disk for make to see, so we'll
# fake it with an empty sentinel file:
docker: .up_to_date Dockerfile

build: Dockerfile $(agent_jar) jmx_exporter.yml
	docker build --build-arg cassandra_version=$(cassandra_version) -t $(image) .
	touch .up_to_date

.PHONY: clean
clean:
	rm -f $(agent_jar) .up_to_date Dockerfile
