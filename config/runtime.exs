import Config

with {:ok, token} <- File.read("/var/run/secrets/kubernetes.io/serviceaccount/token") do
  cacert = File.read!("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
  endpoint = System.get_env("KUBERNETES_SERVICE_HOST")

  Application.put_env(:watcher, :endpoint, endpoint)
  Application.put_env(:watcher, :token, token)
  Application.put_env(:watcher, :cacert, cacert)
end
