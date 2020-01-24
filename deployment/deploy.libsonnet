local clusterinfo = import "clusterinfo.jsonnet";
local flags = import "flags.libsonnet";
local pmk = import "pmk.libsonnet";
local environment = import "environment.libsonnet";
local rbac = import "rbac.libsonnet";
local core_cfg_data = import "feast-core-configmap.libsonnet";
local serving_batch_cfg_data = import "feast-serving-batch-configmap.libsonnet";
local serving_online_cfg_data = import "feast-serving-online-configmap.libsonnet";
local prometheus_statsd_cfg_data = import "prometheus-statsd-exporter-configmap.libsonnet";

{
  name: "pmfeast",
  namespace: "team-data",
  local envFromObj(xs) = [{ name: k, value: std.toString(xs[k]) } for k in std.objectFields(xs)],
  local env_values = environment.base_env($.secrets_env),
  local tag = "v%s" % pmk.thisCommit[0:8],
  local feast_core_configmap = pmk.renderJinja2(
    core_cfg_data.data,
    env_values + {metadata: {tag: tag, release: $.name}}),
  local feast_serving_batch_configmap = pmk.renderJinja2(
    serving_batch_cfg_data.data,
    env_values + {metadata: {tag: tag, release: $.name}}),
  local feast_serving_batch_store = pmk.renderJinja2(
    serving_batch_cfg_data.store,
    env_values + {metadata: {tag: tag, release: $.name}}),
  local feast_serving_online_configmap = pmk.renderJinja2(
    serving_online_cfg_data.data,
    env_values + {metadata: {tag: tag, release: $.name}}),
  local feast_serving_online_store = pmk.renderJinja2(
    serving_online_cfg_data.store,
    env_values + {metadata: {tag: tag, release: $.name}}),
  local prometheus_statsd_exporter_configmap = pmk.renderJinja2(
    prometheus_statsd_cfg_data.data,
    env_values + {metadata: {tag: tag, release: $.name}}),
  local cassandra_configmap = {
    kind: "ConfigMap",
    apiVersion: "v1",
    metadata: {
      name: name_prefix("cassandra-config"),
      labels: {
        app: "feast-serving-online",
        component: "cassandra",
      },
    },
    data: {
      "jmx_exporter.yml": importstr "./docker-cassandra/jmx_exporter.yml",
    },
  },
  manifests: [
    pmk.k8s.configMap(name_prefix("feast-core"), {data: {"application.yaml": feast_core_configmap}}),
    pmk.k8s.configMap(name_prefix("feast-serving-batch"), {data:
           {"application.yaml": feast_serving_batch_configmap,
            "store.yaml": feast_serving_batch_store}}),
    pmk.k8s.configMap(name_prefix("feast-serving-online"), {data:
           {"application.yaml": feast_serving_online_configmap,
            "store.yaml": feast_serving_online_store}}),
    pmk.k8s.configMap(name_prefix("feast-prometheus-statsd-exporter"), {data: {"statsd_mappings.yaml": prometheus_statsd_exporter_configmap}}),
    cassandra_configmap,
  ] + self.values.manifests,
  local name_prefix(t) = "%s-%s" % [self.name, t],
  local pmk_b64(secret, env) = std.base64(pmk.secret(secret, env)),
  local feast = env_values.env,

  values: {

    images:: {
      cassandra: "gcr.io/pm-registry/cassandra:3.11.5"
    },
    tag:: tag,
    service_type:: "ClusterIP",
    common_labels: {
      release: $.name,
    },

    externalHostname:: "%s.%s" % [$.name, $.Cluster.internal_domain],
    externalURL:: "http://%s" % self.externalHostname,

    resources: env_values.resources,
    cassandra: {
      cluster_name: "feast",
      dc_name: "%s-%s" % [$.Cluster.environment, $.Cluster.region],
      keyspace: "feast_v1",

      // Override these to adjust the size of each pod
      ram_req_gb: 8,
      cores_req: 2,
      cores_limit: 2,

      jvm_max_heap_mb: (
          // Formula is from https://docs.datastax.com/en/cassandra/3.0/cassandra/operations/opsTuneJVM.html#opsTuneJVM__tuning-the-java-heap
          local R = self.ram_req_gb * 1024;
          std.max(std.min(R/2, 1024),  std.min(R/4, 8192))
      ),
      jvm_heap_newsize_mb: (
          // Only relevant when using CMS GC (which is the default)
          // (same URL for this one as max_heap_mb)
          std.min(self.cores_limit * 100, self.jvm_max_heap_mb / 4)
      ),
      service_name: "cassandra",

      // Careful here: it is not easy to change the size of EBS volumes after deployment
      data_capacity_gb: 100,
      storage_class: "ssd",

      replicas: 3,
    },

    replicas: 1,

    manifests: [
      pmk.k8s.configMap(name_prefix("core-env"), {data: core_environment}),
      pmk.k8s.secret(name_prefix("secrets"), {data: secrets}),
      pmk.k8s.secret(name_prefix("gcloud-secret"), {data: flow3_secret_mounts}),
      feast_core_deployment,
      feast_core_service_client,
      cassandra_service,
      cassandra_statefulset,
      #feast_batch_deployment,
      #feast_batch_service,
      prometheus_statsd_deployment,
      prometheus_statsd_service,
      #feast_online_deployment,
      #feast_online_service_client,
    ],
  },

  local core_container = {
    name: name_prefix("core"),
    image: "gcr.io/kf-feast/feast-core:0.3.6",
    volumeMounts: [
      { name: name_prefix("feast-core-config"),
        mountPath: "/etc/feast/feast-core",
      },
      { name: name_prefix("feast-core-gcpserviceaccount"),
        mountPath: "/etc/gcloud/service-accounts",
        readOnly: true },
    ],
    ports: [
      {
        containerPort: 8080,
        name: "http",
      },
      {
        containerPort: 6565,
        name: "grpc",
      },
    ],
    livenessProbe: {
      httpGet: {
        path: "/healthz",
        port: 8080,
      },
      initialDelaySeconds: 60,
      periodSeconds: 10,
      successThreshold: 1,
      timeoutSeconds: 5,
      failureThreshold: 5,
    },
    readinessProbe: {
      httpGet: {
        path: "/healthz",
        port: 8080,
      },
      initialDelaySeconds: 15,
      periodSeconds: 10,
      successThreshold: 1,
      timeoutSeconds: 10,
      failureThreshold: 5,
    },
    resources: $.values.resources.core,
    command: [
      "java",
      "-Xms1024m",
      "-Xmx1024m",
      "-jar",
      "/opt/feast/feast-core.jar",
      "--spring.config.location=file:/etc/feast/feast-core/application.yaml"
    ],
    envFrom: [
      {
        configMapRef: {
          name: name_prefix("feast-core")
        }
      }
    ],
  },

  local batch_container = {
    name: name_prefix("serving-batch"),
    image: "gcr.io/kf-feast/feast-serving:0.3.6",
    volumeMounts: [
      { name: name_prefix("feast-serving-batch-config"),
        mountPath: "/etc/feast/feast-serving",
      },
      { name: name_prefix("feast-serving-batch-gcpserviceaccount"),
        mountPath: "/etc/gcloud/service-accounts",
        readOnly: true },
    ],
    ports: [
      {
        containerPort: 8080,
        name: "http",
      },
      {
        containerPort: 6565,
        name: "grpc",
      },
    ],
    resources: $.values.resources.core,
    command: [
      "java",
      "-Xms1024m",
      "-Xmx1024m",
      "-jar",
      "/opt/feast/feast-serving.jar",
      "--spring.config.location=file:/etc/feast/feast-serving/application.yaml",
    ],
    envFrom: [
      {
        configMapRef: {
          name: name_prefix("feast-serving-batch")
        }
      }
    ],
  },

  local online_container = {
    name: name_prefix("serving-online"),
    image: "gcr.io/kf-feast/feast-serving:0.3.6",
    volumeMounts: [
      { name: name_prefix("feast-serving-online-config"),
        mountPath: "/etc/feast/feast-serving",
      },
      { name: name_prefix("feast-serving-online-gcpserviceaccount"),
        mountPath: "/etc/gcloud/service-accounts",
        readOnly: true },
    ],
    ports: [
      {
        containerPort: 8080,
        name: "http",
      },
      {
        containerPort: 6565,
        name: "grpc",
      },
    ],
    resources: $.values.resources.core,
    command: [
      "java",
      "-Xms1024m",
      "-Xmx1024m",
      "-jar",
      "/opt/feast/feast-serving.jar",
      "--spring.config.location=file:/etc/feast/feast-serving/application.yaml"
    ],
    envFrom: [
      {
        configMapRef: {
          name: name_prefix("feast-serving-online")
        }
      }
    ],
  },

  local statsd_container = {
    name: "prometheus-statsd-exporter",
    image: "prom/statsd-exporter:v0.12.1",
    imagePullPolicy: "IfNotPresent",
    volumeMounts: [
      { name: "statsd-config",
        mountPath: "/etc/statsd_conf",
      },
    ],
    env: [
      { name: "HOME",
        value: "/data" },
    ],
    ports: [
      {
        containerPort: 9102,
        name: "metrics",
        protocol: "TCP",
      },
      {
        containerPort: 9125,
        name: "statsd-tcp",
        protocol: "TCP",
      },
      {
        containerPort: 9125,
        name: "statsd-udp",
        protocol: "UDP",
      },
    ],
    resources: {},
    args: [
      "--statsd.mapping-config=/etc/statsd_conf/statsd_mappings.yaml"
    ],
    livenessProbe: {
      httpGet: {
        path: "/#/status",
        port: 9102,
      },
      initialDelaySeconds: 10,
      timeoutSeconds: 10,
    },
    readinessProbe: {
      httpGet: {
        path: "/#/status",
        port: 9102,
      },
      initialDelaySeconds: 10,
      timeoutSeconds: 10,
    },

  },

  local feast_core_deployment = {
    kind: "Deployment",
    apiVersion: "apps/v1",
    metadata: {
      name: name_prefix("feast-core"),
      labels: {
        app: "feast-core",
        component: "core",
      },
    },
    spec: {
      selector: {
        matchLabels: {
          app: "feast-core",
          component: "core",
        } + $.values.common_labels
      },
      replicas: $.values.replicas,
      template: {
        metadata: {
          labels: feast_core_deployment.metadata.labels + $.values.common_labels,
          annotations: {
            "checksum/secret": pmk.sha256(feast_core_configmap),
          },
        },
        spec: {
          terminationGracePeriodSeconds: 30,
          imagePullSecrets: env_values.k8s.pull_secrets,
          containers: [
            core_container,
            sql_sidecar,
          ],
          volumes: [
            { name: name_prefix("feast-core-config"),
              configMap: {
                name: name_prefix("feast-core"),
              },
            },
            { name: name_prefix("feast-core-gcpserviceaccount"),
              secret: {
                secretName: "feast-gcp-service-account",
              },
            },
          ],
        },
      },
    },
  },

  local feast_batch_deployment = {
    kind: "Deployment",
    apiVersion: "apps/v1",
    metadata: {
      name: name_prefix("feast-serving-batch"),
      labels: {
        app: "feast-serving-batch",
        component: "serving",
      },
    },
    spec: {
      selector: {
        matchLabels: {
          app: "feast-serving-batch",
          component: "serving",
        }
      },
      replicas: $.values.replicas,
      template: {
        metadata: {
          labels: feast_batch_deployment.metadata.labels,
          annotations: {
            "checksum/secret": pmk.sha256(feast_serving_batch_configmap),
            "prometheus.io/scrape": "true",
            "prometheus.io/path": "/metrics",
            "prometheus.io/port": "8080",
          },
        },
        spec: {
          terminationGracePeriodSeconds: 30,
          imagePullSecrets: env_values.k8s.pull_secrets,
          containers: [
            batch_container,
          ],
          volumes: [
            { name: name_prefix("feast-serving-batch-config"),
              configMap: {
                name: name_prefix("feast-serving-batch"),
              },
            },
            { name: name_prefix("feast-serving-batch-gcpserviceaccount"),
              secret: {
                secretName: "feast-gcp-service-account",
              },
            },
          ],
        },
      },
    },
  },

  local feast_online_deployment = {
    kind: "Deployment",
    apiVersion: "apps/v1",
    metadata: {
      name: name_prefix("feast-serving-online"),
      labels: {
        app: "feast-serving-online",
        component: "serving",
      },
    },
    spec: {
      selector: {
        matchLabels: {
          app: "feast-serving-online",
          component: "serving",
        } + $.values.common_labels
      },
      replicas: $.values.replicas,
      template: {
        metadata: {
          labels: feast_online_deployment.metadata.labels + $.values.common_labels,
          annotations: {
            "checksum/secret": pmk.sha256(feast_serving_online_configmap),
            "prometheus.io/scrape": "true",
            "prometheus.io/path": "/metrics",
            "prometheus.io/port": "8080",
          },
        },
        spec: {
          terminationGracePeriodSeconds: 30,
          imagePullSecrets: env_values.k8s.pull_secrets,
          containers: [
            online_container,
          ],
          volumes: [
            { name: name_prefix("feast-serving-online-config"),
              configMap: {
                name: name_prefix("feast-serving-online"),
              },
            },
            { name: name_prefix("feast-serving-online-gcpserviceaccount"),
              secret: {
                secretName: "feast-gcp-service-account",
              },
            },
          ],
        },
      },
    },
  },

  local cassandra_statefulset = {
    kind: "StatefulSet",
    apiVersion: "apps/v1",
    metadata: {
      name: $.values.cassandra.service_name,
      labels: {
        app: "feast-serving-online",
        component: "cassandra",
      },
    },

    spec: {
      replicas: $.values.cassandra.replicas,
      serviceName: $.values.cassandra.service_name,
      selector: {
        matchLabels: cassandra_statefulset.spec.template.metadata.labels,
      },
      // Kubernetes doesn't have a way of knowing when it is actually safe to
      // replace pods in this statefulset, so we err on the side of caution
      // and deal with it manually.  If you got here wondering why your pods
      // have not been updated after updating this spec, the answer is that
      // you need to manually delete each pod.
      updateStrategy: {type: "OnDelete"},

      template: {

        metadata: {
          labels: {
            app: "cassandra",
            "feast-infra": "cassandra-replica", // cannot change this without deleting the entire statefulset
          },
        },

        spec: {
          affinity: {
            podAntiAffinity: {
              requiredDuringSchedulingIgnoredDuringExecution: [{
                labelSelector: {
                  // Avoid scheduling more than 1 cassandra pod per k8s node
                  matchExpressions: [{
                    key: "feast-infra",
                    operator: "In",
                    values: ["cassandra-replica"],
                  }],
                },
                topologyKey: "kubernetes.io/hostname",
              }],
            },
          },
          terminationGracePeriodSeconds: 1800,
          containers: [
            { name: "cassandra",
              image: $.values.images.cassandra,
              # We can't just mount the volume at /etc/cassandra/jmx_exporter.yml
              # because docker-entrypoint.sh insists on running chown -R cassandra /etc/cassandra
              # at startup.  Insert usual "this is why we can't have nice things" etc
              command: ["/bin/sh", "-c",
                |||
                  sed -i 's|/etc/cassandra/jmx_exporter.yml|/mnt/cassandra-config/jmx_exporter.yml|' /etc/cassandra/jvm.options;
                  exec /docker-entrypoint.sh cassandra -f
                |||,
              ],
              env: envFromObj({
                MAX_HEAP_SIZE: "%dM" % $.values.cassandra.jvm_max_heap_mb,
                HEAP_NEWSIZE: "%dM" % $.values.cassandra.jvm_heap_newsize_mb,
                CASSANDRA_CLUSTER_NAME: $.values.cassandra.cluster_name,
                CASSANDRA_DC: $.values.cassandra.dc_name,
                CASSANDRA_RACK: "rack1",
                CASSANDRA_ENDPOINT_SNITCH: "GossipingPropertyFileSnitch",
                // Use up to 3 nodes as gossip seeds
                CASSANDRA_SEEDS: std.join(",", [
                  "cassandra-%s.%s" % [n, $.values.cassandra.service_name]
                  for n in std.range(0, std.min($.values.cassandra.replicas, 2))
                ])
              }) + [
                { name: "CASSANDRA_LISTEN_ADDRESS",
                  valueFrom: {
                    fieldRef: {
                      fieldPath: "status.podIP",
                    },
                  },
                },
              ],
              volumeMounts: [
                { name: "cassandra-data",
                  mountPath: "/var/lib/cassandra",
                },
                { name: "cassandra-logs",
                  mountPath: "/var/log/cassandra",
                },
                { name: "cassandra-config",
                  mountPath: "/mnt/cassandra-config",
                },
              ],
              ports: [
                {name: "intra-node",     containerPort: 7000},
                {name: "tls-intra-node", containerPort: 7001},
                {name: "metrics",        containerPort: 7070},
                {name: "jmx",            containerPort: 7199},
                {name: "cql",            containerPort: 9042},
                {name: "thrift",         containerPort: 9160},
              ],
              lifecycle: {
                preStop: {
                  exec: {
                    command: ["/bin/sh", "-c", "nodetool drain"],
                  },
                },
              },
              resources: {
                requests: {
                  memory: "%dGi" % $.values.cassandra.ram_req_gb,
                  cpu: "%dm" % ($.values.cassandra.cores_req * 1000),
                },
                limits: {
                  memory: "%dGi" % $.values.cassandra.ram_req_gb,
                  cpu: "%dm" % ($.values.cassandra.cores_limit * 1000),
                },
              },
            },
          ],
          volumes: [
            { name: "cassandra-logs",
              emptyDir: {},
            },
            { name: "cassandra-config",
              configMap: {
                name: name_prefix("cassandra-config"),
              },
            },
          ],
        },
      },
      volumeClaimTemplates: [{
        metadata: {name: "cassandra-data"},
        spec: {
          storageClassName: $.values.cassandra.storage_class,
          accessModes: ["ReadWriteOnce"],
          resources: {
            requests: {
              storage: "%dGi" % $.values.cassandra.data_capacity_gb,
            },
          },
        },
      }],
    },
  },

  local prometheus_statsd_deployment = {
    kind: "Deployment",
    apiVersion: "apps/v1",
    metadata: {
      name: name_prefix("feast-prometheus-statsd-exporter"),
      labels: {
        app: name_prefix("prometheus-statsd-exporter"),
        component: "prometheus-statsd-exporter",
      },
    },
    spec: {
      selector: {
        matchLabels: {
          app: name_prefix("prometheus-statsd-exporter"),
          component: "prometheus-statsd-exporter",
        }
      },
      replicas: $.values.replicas,
      template: {
        metadata: {
          labels: prometheus_statsd_service.metadata.labels,
          annotations: {
            "checksum/secret": pmk.sha256(prometheus_statsd_exporter_configmap),
            "prometheus.io/scrape": "true",
            "prometheus.io/path": "/metrics",
            "prometheus.io/port": "8080",
          },
        },
        spec: {
          containers: [
            statsd_container,
          ],
          volumes: [
            { name: "statsd-config",
              configMap: {
                name: name_prefix("feast-prometheus-statsd-exporter"),
              },
            },
          ],
        },
      },
    },
  },

  local feast_core_service_client = {

    kind: "Service",
    apiVersion: "v1",
    metadata: {
      name: name_prefix("feast-core-client"),
      labels: {
        app: "feast-core",
        component: "core",
      },
      annotations+: lb_annotations('%s-client' % name_prefix("feast-core")) + {
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '80',
      },
    },
    spec: {
      ports: [
        { port: 80, name: "http", targetPort: 8080},
        { port: 6565, name: "grpc", targetPort: 6565},
      ],
      selector: {
        app: "feast-core",
        component: "core",
      } + $.values.common_labels,
      type: "LoadBalancer",
    },
  },

  local lb_annotations = function(dns_name, external_name=dns_name) {
  } + if $.Cluster.provider == 'aws' then {
    'dns.alpha.kubernetes.io/internal': '%s.%s.%s' % [dns_name, $.namespace, $.Cluster.svc_domain],
    // It's the same domain for internal and external on AWS stage.
    'dns.alpha.kubernetes.io/external': '%s.%s' % [external_name, $.Cluster.internal_domain],
    'service.beta.kubernetes.io/aws-load-balancer-backend-protocol': 'tcp',
    'service.beta.kubernetes.io/aws-load-balancer-internal': '0.0.0.0/0',
  } else if $.Cluster.provider == 'gke' then {
    // On GKE we actually want the internal postmates.net domain for "external to the cluster clients (not public    )"
    'external-dns.alpha.kubernetes.io/hostname': '%s.%s' % [external_name, $.Cluster.internal_domain],
    'cloud.google.com/load-balancer-type': 'Internal',
  } else {},

  local feast_client_service = pmk.k8s.service('%s-client' % name_prefix("feast-core")) {
    spec+: {
      type: 'LoadBalancer',
      ports: [
        { port: 8080, name: "http"},
        { port: 6565, name: "grpc"},
      ],
      selector: {
        app: "feast-core",
        component: "core",
      },
    },
    metadata+: {
      labels: {
        app: "feast-core",
        component: "core",
      },
      annotations+: lb_annotations('%s-client' % name_prefix("feast-core")) + {
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '80',
      },
    },
  },

  local feast_lb_services = [
    pmk.k8s.service('pmfeast-feast-core-client-lb-%s' % pod) + {
      spec+: {
        type: 'LoadBalancer',
        ports: [
          { port: 8080, name: "http", targetPort: 8080},
          { port: 6565, name: "grpc", targetPort: 6565},
        ],
        selector: {
          app: "feast-core",
          component: "core",
        },
      },
      metadata+: {
        labels: {
          app: "feast-core",
        },
        annotations+: lb_annotations('%s.%s' % [pod, name_prefix("feast_core")], pod),
      },
    }
    for pod in std.makeArray($.values.replicas, function(i) '%s' % [name_prefix("feast-core")])
  ],

  local feast_batch_service = {

    kind: "Service",
    apiVersion: "v1",
    metadata: {
      name: name_prefix("feast-serving-batch"),
      labels: {
        app: "feast-serving-batch",
      }
    },
    spec: {
      ports: [
        { port: 80, name: "http", targetPort: 8080},
        { port: 6565, name: "grpc", targetPort: 6565},
      ],
      selector: {
        app: "feast-serving-batch",
        component: "serving",
      },
      type: "ClusterIP",
    },
  },

  local feast_online_service_client = {
    kind: "Service",
    apiVersion: "v1",
    metadata: {
      name: name_prefix("feast-serving-online-client"),
      labels: {
        app: "feast-serving-online",
        component: "serving",
      },
      annotations+: lb_annotations('%s-client' % name_prefix("feast-serving-online")) + {
        'prometheus.io/scrape': 'true',
        'prometheus.io/port': '80',
      },
    },
    spec: {
      ports: [
        { port: 80, name: "http", targetPort: 8080},
        { port: 6565, name: "grpc", targetPort: 6565},
      ],
      selector: {
        app: "feast-serving-online",
        component: "serving",
      } + $.values.common_labels,
      type: "LoadBalancer",
    },
  },

  local cassandra_service = {
    kind: "Service",
    apiVersion: "v1",
    metadata: {
      name: $.values.cassandra.service_name,
      labels: {
        app: "feast-serving-online",
        component: "cassandra",

        // Labels used in prometheus/grafana stuff
        datacenter: $.values.cassandra.dc_name,
        cluster: $.values.cassandra.cluster_name,
      },
      annotations: {
        "prometheus.io/scrape": "true",
        "prometheus.io/port": "7070",
      },
    },

    spec: {
      clusterIP: "None",
      ports: [
        { port: 7000, name: "intra-node" },
        { port: 7001, name: "tls-intra-node"},
        { port: 7070, name: "metrics"},
        { port: 7199, name: "jmx"},
        { port: 9042, name: "cql"},
        { port: 9160, name: "thrift"},
      ],
      selector: {
        "feast-infra": "cassandra-replica",
      },
    },
  },

  local prometheus_statsd_service = {

    kind: "Service",
    apiVersion: "v1",
    metadata: {
      name: name_prefix("feast-prometheus-statsd"),
      labels: {
        app: name_prefix("prometheus-statsd-exporter"), component: "prometheus-statsd-exporter",
      }
    },
    spec: {
      ports: [
        { port: 9102, name: "metrics", targetPort: 9102, protocol: "TCP"},
        { port: 9125, name: "statsd-tcp", targetPort: 9125, protocol: "TCP"},
        { port: 9125, name: "statsd-udp", targetPort: 9125, protocol: "UDP"},
      ],
      selector: {
        app: name_prefix("prometheus-statsd-exporter"),
        component: "prometheus-statsd-exporter",
      },
      type: "ClusterIP",
    },
  },

  local sql_sidecar = {
    name: "cloudsql-proxy",
    image: "gcr.io/cloudsql-docker/gce-proxy:1.16",
    command: ["/cloud_sql_proxy",
              "-instances=features-stage-14344:us-west1:pmfeast=tcp:5432",
              # If running on a VPC, the Cloud SQL proxy can connect via Private IP. See:
              # https://cloud.google.com/sql/docs/mysql/private-ip for more info.
              # "-ip_address_types=PRIVATE",
              "-credential_file=/secrets/cloudsql/credentials.json"],
    securityContext: {
      runAsUser: 2,  # non-root user
      allowPrivilegeEscalation: false,
    },
    volumeMounts: [
      { name: name_prefix("feast-core-gcpserviceaccount"),
        mountPath: "/secrets/cloudsql",
        readOnly: true,
      },
    ]
  },

  local feast_ingress = {
    kind: "Ingress",
    apiVersion: "extensions/v1beta1",
    metadata: {
      name: name_prefix("feast-core"),
      labels: {
        app: "feast-core",
        component: "core",
      }
    },
    spec: {
      rules: [
        {
          host: "pmfeast-feast-core-client.gke-stage.postmates.net",
          http: {
            paths: [
              {
                path: "/",
                backend: {
                  serviceName: name_prefix("feast-core-client"),
                  servicePort: "http"
                },
              },
            ],
          },
        },
      ],
    },
  },

  local core_environment = {
    CLOUDSQL_HOST: feast.cloudsqlHost,
    SPRING_DATASOURCE_USERNAME: feast.springDatasourceUsername,
    SPRING_DATASOURCE_PASSWORD: feast.springDatasourcePassword,
    GOOGLE_APPLICATION_CREDENTIALS: feast.googleApplicationCredentials,
  },

  local secrets = {
    CLOUDSQL_PASSWORD: pmk_b64("flow3/CLOUDSQL_PASSWORD", $.secrets_env),
  },

  local gcp_secret = {
    CLOUDSQL_PASSWORD: pmk_b64("flow3/CLOUDSQL_PASSWORD", $.secrets_env),
  },

  local pg_secrets = {
    "postgresql-password": pmk_b64("flow3/CLOUDSQL_PASSWORD", $.secrets_env),
  },

  local flow3_secret_mounts = {
      "datafall-bigquery-admin.json": pmk_b64("flow3/DATAFALL_BIGQUERY_ADMIN", $.secrets_env),
  },
}
