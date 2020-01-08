{
 data: |||
     feast:
       jobs:
         metrics:
           enabled: false
           host: localhost
           port: 9125
           type: statsd
         options: {}
         runner: DirectRunner
         updates:
           timeoutSeconds: 240
       stream:
         options:
           bootstrapServers: {{ env.bootstrapUrl }}
           partitions: 1
           replicationFactor: 1
           topic: feast
         type: kafka
     grpc:
       enable-reflection: true
       port: 6565
     management:
       metrics:
         export:
           simple:
             enabled: false
           statsd:
             enabled: false
             host: localhost
             port: 8125
     spring:
       datasource:
         driverClassName: org.postgresql.Driver
         password: password1234
         username: pmfeast
       cloud:
         gcp:
           sql:
             database-name: feast
             instance-connection-name: features-stage-14344:us-west1:pmfeast
           project-id: features-stage-14344
       jpa:
         hibernate.ddl-auto: update
         hibernate.naming.physical-strategy=org.hibernate.boot.model.naming: PhysicalNamingStrategyStandardImpl
         properties.hibernate.event.merge.entity_copy_observer: allow
         properties.hibernate.format_sql: true
 |||
}
