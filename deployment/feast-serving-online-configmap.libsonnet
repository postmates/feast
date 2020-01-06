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
       redis-pool-max-size: 128
       redis-pool-max-idle: 64
     jobs:
       staging-location: ""
       store-type: ""
       store-options: {}
   grpc:
     port: 6566
     enable-reflection: true
   server:
     port: 8080

   store.yaml: |
     name: redis
     redis_config:
       host: RELEASE-NAME-redis-headless
       port: 6379
     subscriptions:
     - name: '*'
       project: '*'
       version: '*'
     type: REDIS
 |||
}
