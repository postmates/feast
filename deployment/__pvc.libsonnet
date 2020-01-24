{
  params:: {
    name: error "name?",
    common_labels: {},
    size: null,
    storage_class: "",
  },

  kind: "PersistentVolumeClaim",
  apiVersion: "v1",
  metadata: {
    labels: $.params.common_labels,
    name: $.params.name,
  },
  spec: {
    storageClassName: $.params.storage_class,
    accessModes: ["ReadWriteOnce"],
    [if $.params.storage_class == "" then "selector"]: {
      matchLabels: {
        app: $.metadata.labels.app,
        release: $.params.release,
      },
    },
    resources: {
      requests: {
        storage: std.toString($.params.size),
      },
    },
  },
}
