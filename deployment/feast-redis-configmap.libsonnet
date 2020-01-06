{
 data: |||
   redis.conf: |-
     # User-supplied configuration:
     # Enable AOF https://redis.io/topics/persistence#append-only-file
     appendonly yes
     # Disable RDB persistence, AOF persistence already enabled.
     save ""
   master.conf: |-
     dir /data
     rename-command FLUSHDB ""
     rename-command FLUSHALL ""
   replica.conf: |-
     dir /data
     slave-read-only yes
     rename-command FLUSHDB ""
     rename-command FLUSHALL ""
 |||
}
