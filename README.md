# Watcher

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `watcher` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:watcher, "~> 0.1.0"}
  ]
end
```

## Configuration

By default the configuration used is the service account found within the pod running the watcher, but it can be configured to work with `kubectl proxy --port=<some-port>` or some other endpoint.

```config.exs
config :watcher,
  token: <kubernetes-api-token>,
  cacert: <kubernetes-ca-cert>,
  endpoint: "<kubernetes-endpoint>" # ex. "localhost:8080"

```

Watchers can be configured like so:
```MyWatcher.ex
defmodule Watcher.Test do
  use Watcher,
    api_endpoint: "autoscaling", # Matches What the Kubernetes API has
    api_version: "v2beta2", # Same here
    resource_type: "horizontalpodautoscalers", # Same here
    namespace: "default", # Namespace the resource to watch is in
    resource_name: "my-hpa" # Optional Resource Name to watch. If no Resource Name provided defaults to watching all.
end
```

Service Account Configuration example for watching HPA's:
```
kind: ServiceAccount
apiVersion: v1
metadata:
  name: watcher-service-account

---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: watcher-service-account
rules:
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch"]

---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: watcher-service-account
subjects:
- kind: ServiceAccount
  name: watcher-service-account
roleRef:
  kind: Role
  name: watcher-service-account
  apiGroup: rbac.authorization.k8s.io

```
Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/watcher](https://hexdocs.pm/watcher).

