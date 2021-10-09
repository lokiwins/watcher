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

You can configure the watcher to use token auth, `kubectl proxy`, or the better option would be to use a pod service account and then adjust runtime.exs.

```config.exs
config :watcher,
  token: <kubernetes-api-token>, # Optional
  cacert: <kubernetes-ca-cert>, # Optional
  endpoint: "<kubernetes-endpoint>" # Required ex. "localhost:8080" when using `kubctl proxy --port=8080`

```

Runtime Configuration

```runtime.exs
with {:ok, token} <- File.read("/var/run/secrets/kubernetes.io/serviceaccount/token") do
  cacert = File.read!("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
  endpoint = System.get_env("KUBERNETES_SERVICE_HOST")

  Application.put_env(:watcher, :endpoint, endpoint)
  Application.put_env(:watcher, :token, token)
  Application.put_env(:watcher, :cacert, cacert)
end
```

Watchers can be configured like so:
```MyWatcher.ex
defmodule Watcher.Test do
  use Watcher,
    api_group_name: "autoscaling", # Matches What the Kubernetes API has
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

