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
    network+: {
      enabled: true,
      policies: [
        {
          name: "pgpool",
          cidrs: ["10.33.13.0/27", "10.33.13.32/27"], # pgpool stage subnets - https://github.com/postmates/postal-main/blob/master/tf/pgpool.tf
          ports: [
            {
              port: 5432,
              protocol: "TCP",
            },
            {
              port: 5433,
              protocol: "TCP",
            },
          ],
        },
        {
          name: "posOrderingDb",
          # https://github.com/postmates/pos-ordering/blob/master/deployment/tf/main.tf#L19
          cidrs: ["10.33.6.0/28", "10.33.6.16/28", "10.33.6.32/28"],
          ports: [
            {
              port: 5432,
              protocol: "TCP",
            }
          ],
        },
        {
          name: "developerApiDb",
          # https://github.com/postmates/developer-api/blob/master/deployment/tf/developer_api_resources.tf#L24
          cidrs: ["10.33.7.0/28", "10.33.7.16/28", "10.33.7.32/28"],
          ports: [
            {
              port: 5432,
              protocol: "TCP",
            }
          ],
        },
        {
          name: "hcsDb",
          # https://github.com/postmates/help-center/blob/e81eabfda74b7f54092d834eb899497fc6c26a6d/tf/main.tf#L31
          cidrs: ["10.33.8.0/28", "10.33.8.16/28", "10.33.8.32/28"],
          ports: [
            {
              port: 5432,
              protocol: "TCP",
            }
          ],
        },
        {
          name: "riskElasticSearch",
          # https://github.com/postmates/pi-pegasus/blob/master/tf/es_resources.tf#L7-L7
          cidrs: ["10.33.5.0/28"],
          ports: [
            {
              port: 80,
              protocol: "TCP",
            }
          ],
        },
        {
          name: "postalMainMemcache",
          # https://github.com/postmates/postal-main/blob/master/tf/aws/memcached.tf#L53
          cidrs: ["10.33.13.96/27", "10.33.13.128/27", "10.33.13.160/27", "10.33.13.240/28"],
          ports: [
            {
              port: 6363,
              protocol: "TCP",
            }
          ],
        },
        {
          name: "fleetDashboardRedis",
          # http://github.com/postmates/fleet-dashboard
          cidrs: ["10.33.17.48/28"],
          ports: [
            {
              port: 6379,
              protocol: "TCP",
            }
          ],
        },
      ],
    },
  },
  Environment {
    environment: "prod",
    env: EnvVars {
      cloudsqlHost: "34.94.181.148",
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
    network+: {
      enabled: true,
      policies: [
        {
          name: "pgpool",
          # pgpool prod subnets - https://github.com/postmates/postal-main/blob/master/tf/pgpool.tf
          cidrs: ["10.1.14.0/27", "10.1.14.32/27"],
          ports: [
            {
              port: 5432,
              protocol: "TCP",
            },
            {
              port: 5433,
              protocol: "TCP",
            },
          ],
        },
        {
          name: "riskElasticSearch",
          # https://github.com/postmates/pi-pegasus/blob/master/tf/es_resources.tf#L48-L48
          cidrs: ["10.1.38.16/28"],
          ports: [
            {
              port: 80,
              protocol: "TCP",
            }
          ],
        },
        {
          name: "posOrderingDb",
          # https://github.com/postmates/pos-ordering/blob/master/deployment/tf/main.tf#L33
          cidrs: ["10.1.16.0/27", "10.1.16.32/27"],
          ports: [
            {
              port: 5432,
              protocol: "TCP",
            }
          ],
        },
        {
          name: "merchantSalesforceDataDb",
          # https://github.com/postmates/merchant-salesforce-data/blob/master/tf/rds.tf#L33
          cidrs: ["10.1.10.0/27", "10.1.10.32/27"],
          ports: [
            {
              port: 5432,
              protocol: "TCP",
            }
          ],
        },
        {
          name: "developerApiDb",
          # https://github.com/postmates/developer-api/blob/master/deployment/tf/developer_api_resources.tf#L65
          cidrs: ["10.1.15.0/27", "10.1.15.32/27"],
          ports: [
            {
              port: 5432,
              protocol: "TCP",
            }
          ],
        },
        {
          name: "postalMainMemcache",
          # https://github.com/postmates/postal-main/blob/master/tf/aws/memcached.tf#L23
          cidrs: ["10.1.14.64/27", "10.1.14.96/27"],
          ports: [
            {
              port: 6363,
              protocol: "TCP",
            }
          ],
        },
        {
          name: "fleetDashboardRedis",
          # https://github.com/postmates/fleet-dashboard/
          cidrs: ["10.1.7.0/28"],
          ports: [
            {
              port: 6379,
              protocol: "TCP",
            }
          ],
        },
      ],
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
