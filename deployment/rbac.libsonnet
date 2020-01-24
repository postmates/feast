[
  {
    apiVersion: "v1",
    kind: "ServiceAccount",
    metadata: {
      name: "flow3-k8s-executor-team-data",
    },
    imagePullSecrets: [
      {name: "gcr.io-puller-temp"},
    ],
  },
  {
    kind: "Role",
    apiVersion: "rbac.authorization.k8s.io/v1",
    metadata: {
      namespace: "team-data",
      name: "flow3-pod-admin-team-data",
    },
    rules: [
      {
        apiGroups: [""], # "" indicates the core API group
        resources: ["pods"],
        verbs: ["get", "watch", "list", "create", "delete"],
      },
    ],
  },
  {
    apiVersion: "rbac.authorization.k8s.io/v1beta1",
    kind: "RoleBinding",
    metadata: {
      name: "flow3-admin-rbac-team-data",
      namespace: "team-data",
    },
    subjects: [
      {
        kind: "ServiceAccount",
        name: "flow3-k8s-executor-team-data",
        namespace: "team-data",
      },
    ],
    roleRef: {
      kind: "Role",
      name: "flow3-pod-admin-team-data",
      apiGroup: "rbac.authorization.k8s.io",
    },
  },
  //{
  //  apiVersion: "v1",
  //  kind: "LimitRange",
  //  metadata: {
  //    name: "team-data",
  //  },
  //  spec: {
  //    limits: [
  //      {
  //        default: {
  //          memory: "512Mi",
  //          cpu: '1',
  //        },
  //        defaultRequest: {
  //          memory: "256Mi",
  //          cpu: ".25",
  //        },
  //        type: "Container",
  //      },
  //    ],
  //  }
  //}
]
