local clusterinfo = import "clusterinfo.jsonnet";
local pmk = import "pmk.libsonnet";

(import "deployment/deploy.libsonnet") + {
  namespace: "team-data",

  deployments+: {
    prod: {
      cluster: "gke-prod",
      secrets_env:: "prod",
    },
    stage: {
      cluster: "gke-stage",
      secrets_env:: "stage",
      values+: {
        cassandra+: {
          data_capacity_gb: 25,  // per statefulset replica
          cores_req: 1,
          cores_limit: 1,
        }
      }
    },
  }
}
