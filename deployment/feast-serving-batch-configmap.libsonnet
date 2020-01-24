{
 data: |||
   feast:
     version: 0.3
     core-host: {{ metadata.release }}-feast-core
     core-grpc-port: 6565
     tracing:
       enabled: false
       tracer-name: jaeger
       service-name: feast-serving
     store:
       config-path: /etc/feast/feast-serving/store.yaml
     jobs:
       staging-location: gs://pmfeast-staging-features-stage
       store-type: "CASSANDRA"
       store-options: {}
   grpc:
     port: 6566
     enable-reflection: true
   server:
     port: 8080
 |||,
 store: |||
   name: bigquery
   type: BIGQUERY
   bigquery_config:
     dataset_id: features-stage-14344:feast
     project_id: features-stage-14344
 |||
}
