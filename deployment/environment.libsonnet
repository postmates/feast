local EnvVars = {
  springDatasourceUsername: "postgres",
  springDatasourcePassword: "TODOSETPASS",
  googleApplicationCredentials: "/etc/gcloud/service-accounts/key.json",
  airflowHome: "/usr/local/airflow",
  cloudsqlHost: "",
};

local Environment = {
  // alias (String, unique): Shorthand name that can be used in place of fullname in lookups
  alias: self.environment,

  // environment (String): Postmates environment name, like "stage" "prod" etc
  environment: error "missing environment",

  // env (EnvVars): environment key values
  env: error "missing env",

  // k8s (Object): environment key values
  k8s: error "missing k8s",

  // resources (Object): environment key values
  resources: error "missing resources",

  // network (Object): network values
  network: {},
};

local environments = [
  Environment {
    environment: "stage",
    env: EnvVars {
      cloudsqlHost: "34.94.68.56",
      bootstrapUrl: "kafka-events-client.gke-stage.postmates.net:9093",
    },
    k8s: {
      pull_secrets: [
        {name: "postmates-k8s-deployer-pull-secret"},
        {name: "gcr.io-puller-temp"},
      ],
    },
    resources: {
      init: {
        requests: {
          cpu: ".5",
          memory: "1Gi"
        },
        limits: {
          cpu: "1",
          memory: "2Gi",
        }
      },
      scheduler: {
        requests: {
          cpu: "2",
          memory: "4Gi"
        },
        limits: {
          cpu: "2",
          memory: "4Gi",
        }
      },
      core: {
        requests: {
          cpu: "1000m",
          memory: "1024Mi",
        },
        limits: {
          cpu: "2000m",
          memory: "2048Mi",
        }
      }
    },
  },
  Environment {
    environment: "prod",
    env: EnvVars {
      cloudsqlHost: "34.94.181.148",
      bootstrapUrl: "kafka-events-client.gke-prod.postmates.net:9093",
    },
    k8s: {
      pull_secrets: [
        {name: "postmates-k8s-deployer-pull-secret"},
        {name: "gcr.io-puller-temp"},
      ],
    },
    resources: {
      init: {
        requests: {
          cpu: ".5",
          memory: "1Gi"
        },
        limits: {
          cpu: "1",
          memory: "2Gi",
        }
      },
      scheduler: {
        requests: {
          cpu: "2",
          memory: "4Gi"
        },
        limits: {
          cpu: "2",
          memory: "4Gi",
        }
      },
      webserver: {
        requests: {
          cpu: "2",
          memory: "8Gi",
        },
        limits: {
          cpu: "4",
          memory: "16Gi",
        }
      }
    },
  },
];

{
  base_env(env):: (
    local match(x) = env == x.environment || env == x.alias,
          matches = [x for x in environments if match(x)];
    if std.length(matches) == 0 then
        error "Failed to look up environment with env '%s': No environments found" % env
      else if std.length(matches) == 1 then
        matches[0]
      else
        error "Failed to look up environment with env '%s': Got multiple environments with that env: %s" % [
          env,
          std.join(", ", [c.fullname for c in matches]),
        ]
  ),
  network_policies(networks):: (
      {
        apiVersion: "networking.k8s.io/v1",
        kind: "NetworkPolicy",
        metadata: {
          name: "allow-egress-from-flow3",
          labels: {
            app: "flow3",
          }
        },
        spec: {
          podSelector: {
            matchLabels: {
              release: "flow3",
            },
          },
          policyTypes: [ "Egress" ],
          ["egress"]: [
            {
              ["to"]: [
                {
                  ["ipBlock"]: {
                    ["cidr"]: cidr,
                  }
                }
              for cidr in network.cidrs ],
              ["ports"]: network.ports
            }
          for network in networks ],
        },
      }
  ),
}
