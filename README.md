# LibclusterECS

ECS strategy for [libcluster]

Currently supports clustering within a service. Makes use of the [Task Metadata
Endpoint] to resolve the current cluster, service, and task.

## Installation

```elixir
def deps do
  [
    {:libcluster_ecs, github: "verypossible/libcluster_ecs"}
  ]
end
```

[libcluster]: https://github.com/bitwalker/libcluster
[Task Metadata Endpoint]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-metadata-endpoint.html
