local clusterinfo = import "clusterinfo.jsonnet";
local flags = import "flags.libsonnet";
local pmk = import "pmk.libsonnet";
local environment = import "environment.libsonnet";
local rbac = import "rbac.libsonnet";
local core_cfg_data = import "feast-core-configmap.libsonnet";
local serving_cfg_data = import "feast-serving-configmap.libsonnet";

{
  name: "feast",
  namespace: "team-data",
  local env_values = environment.base_env($.secrets_env),
  local tag = "v%s" % pmk.thisCommit[0:8],
  local clf = "[%%(blue)s%%(asctime)s%%(reset)s] {{%%(blue)s%%(filename)s:%%(reset)s%%(lineno)d}} %%(log_color)s%%(levelname)s%%(reset)s - %%(log_color)s%%(message)s%%(reset)s",
  local lf = "[%%(asctime)s] {{%%(filename)s:%%(lineno)d}} %%(levelname)s - %%(message)s",
  local slf = "%%(asctime)s %%(levelname)s - %%(message)s",
  local lft = '{{ ti.dag_id }}/{{ ti.task_id }}/{{ execution_date.strftime("%%Y-%%m-%%dT%%H:%%M:%%S") }}/{{ try_number }}.log',
  local lpft = "{{ filename }}.log",
  local lit = "{{dag_id}}-{{task_id}}-{{execution_date}}-{{try_number}}",
  local feast_core_configmap = pmk.renderJinja2(
    core_cfg_data.data,
    env_values + {metadata: {tag: tag, release: $.name}} + {cfg: {clf: clf, lf: lf, slf: slf, lft: lft, lpft: lpft, lit: lit}}),
  local feast_serving_configmap = pmk.renderJinja2(
    serving_cfg_data.data,
    env_values + {metadata: {tag: tag, release: $.name}} + {cfg: {clf: clf, lf: lf, slf: slf, lft: lft, lpft: lpft, lit: lit}}),
  manifests: [
    pmk.k8s.configMap("feast-core-configmap", {data: {"application.yaml": feast_core_configmap}}),
    pmk.k8s.configMap("feast-serving-configmap", {data: {"application.yaml": feast_serving_configmap}}),
  ] + self.values.manifests + rbac + [environment.network_policies(env_values.network.policies)],
  local name_prefix(t) = "%s-%s" % [self.name, t],
  local full_image() = "%s:%s" % [self.values.image, self.values.tag],
  local pmk_b64(secret, env) = std.base64(pmk.secret(secret, env)),
  local feast = env_values.env,
  local etl_connection_string(user, password, host, port, db) = std.base64("postgresql://%s:%s@%s:%s/%s" % [user, password, host, port, db]),

  values: {

    image:: "gcr.io/pm-registry/flow3",
    tag:: tag,
    service_type:: "ClusterIP",
    common_labels: {
      app: $.name,
    },

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
      //flow3_webserver,
      //ingress,
    ],
  },

  local ingress = {
    kind: "Ingress",
    apiVersion: "extensions/v1beta1",
    metadata: {
      name: $.name,
      labels: $.values.common_labels,
      annotations: {
        "kubernetes.io/ingress.class": "nginx-internal",
      },
    },
    spec: {
      backend: {
        serviceName: name_prefix("airflow"),
        servicePort: "http",
      },
      rules: [
        {
          host: $.values.externalHostname,
          http: {
            paths: [
              {
                backend: {
                  serviceName: $.name,
                  servicePort: "http",
                },
              },
            ],
          },
        },
      ],
    },
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
    name: name_prefix("core"),
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
      "/opt/feast/feast-core.jar",
      "--spring.config.location=file:/etc/feast/feast-core/application.yaml"
    ],
    envFrom: [
      {
        configMapRef: {
          name: name_prefix("serving-configmap")
        }
      }
    ],
  },


  local feast_core_deployment = {
    kind: "Deployment",
    apiVersion: "apps/v1beta1",
    selector: {
      matchLabels: {
        app: name_prefix("core"),
        component: "core",
      }
    },
    metadata: {
      name: name_prefix("core"),
      labels: {
        app: name_prefix("core"),
        component: "core",
        release: $.name,
      },
    },
    spec: {
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
    apiVersion: "apps/v1beta1",
    selector: {
      matchLabels: {
        app: name_prefix("serving-batch"),
        component: "serving",
      }
    },
    metadata: {
      name: name_prefix("serving-batch"),
      labels: {
        app: name_prefix("serving-batch"),
        component: "serving",
        release: $.name,
      },
    },
    spec: {
      replicas: $.values.replicas,
      template: {
        metadata: {
          labels: feast_batch_service.metadata.labels,
          annotations: {
            "prometheus.io/scrape": "false",
            "prometheus.io/path": "/admin/metrics",
            "prometheus.io/port": 8081,
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


  local feast_core_service = {

    kind: "Service",
    apiVersion: "v1",
    metadata: {
      name: $.name,
      labels: {
        app: name_prefix("core"),
        release: $.name,
      }
    },
    spec: {
      ports: [
        { port: 80, name: "http", targetPort: 8080},
        { port: 6565, name: "grpc", targetPort: 6565},
      ],
      selector: {
        matchLabels: {
          app: name_prefix("core"),
          component: "core",
          release: $.name
        }
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
        release: $.name,
      }
    },
    spec: {
      ports: [
        { port: 80, name: "http", targetPort: 8080},
        { port: 6565, name: "grpc", targetPort: 6565},
      ],
      selector: {
        matchLabels: {
          app: name_prefix("serving-batch"),
          component: "serving",
          release: $.name
        }
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

  local flow3_secret_mounts = {
      "bigquery.json": pmk_b64("flow3/BIGQUERY_JSON_SECRET", $.secrets_env),
      "aqueduct-bigquery-read.json": pmk_b64("flow3/AQUEDUCT_BIGQUERY_READ", $.secrets_env),
      "datafall-bigquery-admin.json": pmk_b64("flow3/DATAFALL_BIGQUERY_ADMIN", $.secrets_env),
      "reporting-bigquery-admin.json": pmk_b64("flow3/REPORTING_BIGQUERY_ADMIN", $.secrets_env),
      "monitoring-bigquery-admin.json": pmk_b64("flow3/MONITORING_BIGQUERY_ADMIN", $.secrets_env),
      "pmf_gcloud_credentials.json": pmk_b64("pmf/GOOGLE_APPLICATION_CREDENTIALS", $.secrets_env),
      "data-science-dev.json": pmk_b64("flow3/DATA_SCIENCE_DEV", $.secrets_env),
      "dataflow-sa.json": pmk_b64("flow3/DATAFLOW_SA", $.secrets_env),
      "datafall-sales-ops-bigquery-admin.json": pmk_b64("flow3/DATAFALL_SALES_OPS_BIGQUERY_ADMIN", $.secrets_env),
  },
}
