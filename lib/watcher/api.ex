defmodule Watcher.Api do
  use HTTPoison.Base

  def process_url(path) do
    endpoint = Application.get_env(:watcher, :endpoint, "localhost:8080")

    "#{endpoint}#{path}"
  end

  def process_request_headers(headers) do
    token = Application.get_env(:watcher, :token, nil)

    case token do
      nil -> headers
      token -> [{"Authorization", "Bearer #{token}"} | headers]
    end
  end

  def process_request_options(options) do
    cacert = Application.get_env(:watcher, :cacert, nil)

    Keyword.put(options, :ssl, [cacerts: [cacert]])
  end

end
