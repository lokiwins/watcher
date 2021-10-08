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
    namespace: "staging", # Namespace the resource to watch is in
    resource_names: ["a", "b", "c"] # Optional List of resource names to watch. If not provided all will be watched.
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/watcher](https://hexdocs.pm/watcher).

