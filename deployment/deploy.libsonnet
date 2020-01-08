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
  local env_values = environment.base_env($.secrets_env),
  local tag = "v%s" % pmk.thisCommit[0:8],
  local feast_core_configmap = pmk.renderJinja2(
    core_cfg_data.data,
    env_values + {metadata: {tag: tag, release: $.name}}),
  local feast_serving_batch_configmap = pmk.renderJinja2(
    serving_batch_cfg_data.data,
    env_values + {metadata: {tag: tag, release: $.name}}),
  local feast_serving_online_configmap = pmk.renderJinja2(
    serving_online_cfg_data.data,
    env_values + {metadata: {tag: tag, release: $.name}}),
  local prometheus_statsd_exporter_configmap = pmk.renderJinja2(
    prometheus_statsd_cfg_data.data,
    env_values + {metadata: {tag: tag, release: $.name}}),
  manifests: [
    pmk.k8s.configMap("feast-core-configmap", {data: {"application.yaml": feast_core_configmap}}),
    pmk.k8s.configMap("feast-serving-batch-configmap", {data: {"application.yaml": feast_serving_batch_configmap}}),
    pmk.k8s.configMap("feast-serving-online-configmap", {data: {"application.yaml": feast_serving_online_configmap}}),
    pmk.k8s.configMap("feast-prometheus-statsd-exporter", {data: {"application.yaml": prometheus_statsd_exporter_configmap}}),
  ] + self.values.manifests,
  local name_prefix(t) = "%s-%s" % [self.name, t],
  local pmk_b64(secret, env) = std.base64(pmk.secret(secret, env)),
  local feast = env_values.env,

  values: {

    image:: "gcr.io/kf-feast/",
    tag:: tag,
    service_type:: "ClusterIP",
    common_labels: {
      app: $.name,
    },
    pvcStorageClass: "",

    externalHostname:: "%s.%s" % [$.name, $.Cluster.internal_domain],
    externalURL:: "http://%s" % self.externalHostname,

    resources: env_values.resources,

    replicas: 1,

    manifests: [
      pmk.k8s.configMap(name_prefix("core-env"), {data: core_environment}),
      pmk.k8s.secret(name_prefix("secrets"), {data: secrets}),
      pmk.k8s.secret(name_prefix("gcloud-secret"), {data: flow3_secret_mounts}),
      feast_core_deployment,
      feast_core_service,
      feast_batch_deployment,
      feast_batch_service,
      prometheus_statsd_deployment,
      prometheus_statsd_service,
      prometheus_statsd_pvc,
      #feast_online_deployment,
      #feast_online_service,
    ],
  },

  local core_container = {
    name: name_prefix("core"),
    image: "gcr.io/kf-feast/feast-core:0.3.2",
    volumeMounts: [
      { name: name_prefix("feast-core-config"),
        mountPath: "/etc/feast/feast-serving",
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
          name: name_prefix("core-configmap")
        }
      }
    ],
  },

  local batch_container = {
    name: name_prefix("serving-batch"),
    image: "gcr.io/kf-feast/feast-serving:0.3.2",
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
      "--spring.config.location=file:/etc/feast/feast-serving/application.yaml"
    ],
    envFrom: [
      {
        configMapRef: {
          name: name_prefix("serving-batch-configmap")
        }
      }
    ],
  },

  local online_container = {
    name: name_prefix("serving-online"),
    image: "gcr.io/kf-feast/feast-serving:0.3.2",
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
          name: name_prefix("serving-online-configmap")
        }
      }
    ],
  },

  local statsd_container = {
    name: "prometheus-statsd-exporter",
    image: "prom/statsd-exporter:v0.12.1",
    imagePullPolicy: "IfNotPresent",
    volumeMounts: [
      { name: "storage-volume",
        mountPath: "/data",
      },
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
        app: name_prefix("core"),
        component: "core",
      },
    },
    spec: {
      selector: {
        matchLabels: {
          app: name_prefix("core"),
          component: "core",
        }
      },
      replicas: $.values.replicas,
      template: {
        metadata: {
          labels: feast_core_service.metadata.labels,
          annotations: {
            "checksum/secret": pmk.sha256(feast_core_configmap),
          },
        },
        spec: {
          terminationGracePeriodSeconds: 30,
          imagePullSecrets: env_values.k8s.pull_secrets,
          containers: [
            core_container,
          ],
          volumes: [
            { name: name_prefix("feast-core-config"),
              configMap: {
                name: name_prefix("feast-core"),
              },
            },
            { name: name_prefix("feast-core-gcpserviceaccount"),
              secret: {
                secretName: name_prefix("feast-gcp-service-account"),
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
        app: name_prefix("serving-batch"),
        component: "serving",
      },
    },
    spec: {
      selector: {
        matchLabels: {
          app: name_prefix("serving-batch"),
          component: "serving",
        }
      },
      replicas: $.values.replicas,
      template: {
        metadata: {
          labels: feast_batch_service.metadata.labels,
          annotations: {
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
                secretName: name_prefix("feast-gcp-service-account"),
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
        app: name_prefix("serving-online"),
        component: "serving",
      },
    },
    spec: {
      selector: {
        matchLabels: {
          app: name_prefix("serving-online"),
          component: "serving",
        }
      },
      replicas: $.values.replicas,
      template: {
        metadata: {
          labels: feast_online_service.metadata.labels,
          annotations: {
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
                secretName: name_prefix("feast-gcp-service-account"),
              },
            },
          ],
        },
      },
    },
  },

  local postgresql_statefulset = {
    kind: "StatefulSet",
    apiVersion: "apps/v1",
    metadata: {
      name: name_prefix("postgresql"),
      labels: {
        app: "postgresql",
      },
    },
    spec: {
      selector: {
        matchLabels: {
          app: "postgresql",
          role: "master",
        }
      },
      serviceName: name_prefix("postgresql-headless"),
      replicas: 1,
      updateStrategy: {
        type: "RollingUpdate",
      },
      template: {
        metadata: {
          name: name_prefix("postgresql"),
          labels: {
            app: "postgresql"
          },
        },
        spec: {
          securityContext: {
            fsGroup: 1001
          },
          initContainers: [
            #pg_init_container
          ],
          containers: [
            #pg_container,
          ],
          volumes: [
            { name: name_prefix("feast-core-config"),
              configMap: {
                name: name_prefix("feast-core"),
              },
            },
            { name: name_prefix("feast-core-gcpserviceaccount"),
              secret: {
                secretName: name_prefix("feast-gcp-service-account"),
              },
            },
          ],
        },
      },
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
                name: name_prefix("prometheus-statsd-exporter-config"),
              },
            },
            { name: "storage-volume",
              persistentVolumeClaim: {
                claimName: name_prefix("prometheus-statsd-exporter")
              }
            },
          ],
        },
      },
    },
  },

  local prometheus_statsd_pvc = (import "__pvc.libsonnet") + {params+: {
        name: name_prefix("prometheus-statsd-exporter"),
        common_labels: $.values.common_labels,
        size: "20Gi",
        storage_class: $.values.pvcStorageClass,
        release: $.name
    }
  },

  local feast_core_service = {

    kind: "Service",
    apiVersion: "v1",
    metadata: {
      name: $.name,
      labels: {
        app: name_prefix("core"),
        component: "core"
      }
    },
    spec: {
      ports: [
        { port: 80, name: "http", targetPort: 8080},
        { port: 6565, name: "grpc", targetPort: 6565},
      ],
      selector: {
        app: name_prefix("core"),
        component: "core",
      },
      type: "ClusterIP",
    },
  },

  local feast_batch_service = {

    kind: "Service",
    apiVersion: "v1",
    metadata: {
      name: $.name,
      labels: {
        app: name_prefix("serving-batch"),
        component: "serving"
      }
    },
    spec: {
      ports: [
        { port: 80, name: "http", targetPort: 8080},
        { port: 6565, name: "grpc", targetPort: 6565},
      ],
      selector: {
        app: name_prefix("serving-batch"),
        component: "serving",
      },
      type: "ClusterIP",
    },
  },

  local feast_online_service = {

    kind: "Service",
    apiVersion: "v1",
    metadata: {
      name: $.name,
      labels: {
        app: name_prefix("serving-online"),
      }
    },
    spec: {
      ports: [
        { port: 80, name: "http", targetPort: 8080},
        { port: 6565, name: "grpc", targetPort: 6565},
      ],
      selector: {
        app: name_prefix("serving-online"),
        component: "serving",
      },
      type: "ClusterIP",
    },
  },

  local prometheus_statsd_service = {

    kind: "Service",
    apiVersion: "v1",
    metadata: {
      name: $.name,
      labels: {
        app: name_prefix("prometheus-statsd-exporter"),
        component: "prometheus-statsd-exporter",
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

  local postgresql_headless_service = {

    kind: "Service",
    apiVersion: "v1",
    metadata: {
      name: name_prefix("postgresql-headless"),
      labels: {
        app: "postgresql",
      }
    },
    spec: {
      ports: [
        { port: 5432, name: "postgresql", targetPort: "postgresql"},
      ],
      selector: {
        app: "postgresql",
      },
      type: "ClusterIP",
      clusterIP: "None"
    },
  },

  local postgresql_service = {

    kind: "Service",
    apiVersion: "v1",
    metadata: {
      name: name_prefix("postgresql"),
      labels: {
        app: name_prefix("postgresql"),
      }
    },
    spec: {
      ports: [
        { port: 5432, name: "postgresql", targetPort: "postgresql"},
      ],
      selector: {
        app: "postgresql",
        role: "master"
      },
      type: "ClusterIP",
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

  local pg_secrets = {
    "postgresql-password": pmk_b64("flow3/CLOUDSQL_PASSWORD", $.secrets_env),
  },

  local flow3_secret_mounts = {
      "datafall-bigquery-admin.json": pmk_b64("flow3/DATAFALL_BIGQUERY_ADMIN", $.secrets_env),
  },
}
