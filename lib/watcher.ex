defmodule Watcher do
  defmacro __using__(config \\ []) do

    quote do
      @config unquote(config)

      def child_spec(config) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [config]},
          restart: :permanent,
          shutdown: 500
        }
      end

      def start_link(_args) do
        Connection.start_link(Watcher, config(), name: __MODULE__)
      end

      def config do
        config = Application.get_application(__MODULE__)
        |> Application.get_env(__MODULE__, [])

        Keyword.merge(@config, config)
      end

      def state, do: GenServer.call(__MODULE__, :state)

    end
  end

  use Connection
  require Logger
  alias Watcher.Api

  defstruct resource_version: nil, response: nil, buffer: "", namespace: nil, watch_state: %{}, watch_path: nil

  @default_opts [
    recv_timeout: 310_000
  ]

  @doc false
  @impl true
  def init(config) do
    # Setup Initial State
    namespace = Keyword.get(config, :namespace)
    api_endpoint = Keyword.get(config, :api_group_name)
    api_version = Keyword.get(config, :api_version)
    resource_type = Keyword.get(config, :resource_type)
    resource_name = Keyword.get(config, :resource_name, nil)
    timeout = Keyword.get(config, :timeout, 300)

    # Initial Get Request to setup state.
    path = generate_get_path(api_endpoint, api_version, namespace, resource_type, resource_name, timeout)
    {:ok, response} = make_request(path, %__MODULE__{namespace: namespace})

    watch_state = Map.get(response, :body)
    |> Jason.decode!()
    |> Map.get("items")
    |> Enum.reduce(%{}, fn hpa_spec, acc ->
      Map.put(acc, hpa_spec["metadata"]["name"], hpa_spec)
    end)


    # Start watch
    {:connect, :init, %__MODULE__{namespace: namespace, watch_state: watch_state, watch_path: generate_watch_path(api_endpoint, api_version, namespace, resource_type, resource_name, timeout)}}
  end

  @doc false
  @impl true
  def connect(_, state) do
    path = state.watch_path

    case make_request(path, state, async: :once, stream_to: self()) do
      {:ok, response} ->
        {:ok, %{state | response: response}}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error(reason)
        {:backoff, 1000, state}
    end
  end

  @doc false
  @impl true
  def disconnect(_, state) do
    {:backoff, 1000, state}
  end

  @doc false
  @impl true
  def handle_info(%HTTPoison.AsyncStatus{} = status, state) do
    case status do
      %{code: 200} -> Logger.info(inspect(status))
      %{code: _code} -> Logger.error(inspect(status))
    end
    next_response(state)
  end

  @doc false
  @impl true
  def handle_info(%HTTPoison.AsyncHeaders{} = headers, state) do
    Logger.info(inspect(headers))
    next_response(state)
  end

  @doc false
  @impl true
  def handle_info(%HTTPoison.AsyncChunk{} = chunk, state) do
    Logger.debug(inspect(chunk))

    buffer = state.buffer <> chunk.chunk

    messages = String.split(buffer, "\n")
    {buffer, messages} = List.pop_at(messages, -1)

    state = %{state | buffer: buffer}

    state = Enum.reduce messages, state, fn message, state ->
      Logger.debug(message)
      event = Jason.decode!(message)

      watch_state = state.watch_state
      |> Map.put(event["object"]["metadata"]["name"], event["object"])

      Map.put(state, :resource_version, event["object"]["metadata"]["resourceVersion"])
      |> Map.put(:watch_state, watch_state)
    end

    next_response(state)
  end

  @doc false
  @impl true
  def handle_info(%HTTPoison.AsyncEnd{} = async_end, state) do
    Logger.info(inspect(async_end))
    {:disconnect, async_end, state}
  end

  @doc false
  @impl true
  def handle_call(:state, _, state) do
    {:reply, state.watch_state, state}
  end

  defp make_request(path, state, options \\ []) do
    opts = Keyword.merge(@default_opts, options)
    path = if state.resource_version do
      "#{path}&resourceVersion=#{state.resource_version}"
    else
      path
    end

    Logger.info("GET #{path}")

    Api.get(path, [], opts)
  end

  defp next_response(state) do
    with {:ok, response} <- HTTPoison.stream_next(state.response) do
      state = %{state | response: response}
      {:noreply, state}
    else
      {:error, %{reason: reason}} ->
        Logger.error(reason)
        {:connect, :error, state}
    end
  end

  defp generate_get_path(api_endpoint, api_version, namespace, resource_type, nil, timeout),
    do: "/apis/#{api_endpoint}/#{api_version}/namespaces/#{namespace}/#{resource_type}?timeoutSeconds=#{timeout}"
  defp generate_get_path(api_endpoint, api_version, namespace, resource_type, resource_name, timeout),
    do: "/apis/#{api_endpoint}/#{api_version}/namespaces/#{namespace}/#{resource_type}/#{resource_name}?timeoutSeconds=#{timeout}"
  defp generate_watch_path(api_endpoint, api_version, namespace, resource_type, nil, timeout),
    do: "/apis/#{api_endpoint}/#{api_version}/watch/namespaces/#{namespace}/#{resource_type}?timeoutSeconds=#{timeout}"
  defp generate_watch_path(api_endpoint, api_version, namespace, resource_type, resource_name, timeout),
    do: "/apis/#{api_endpoint}/#{api_version}/watch/namespaces/#{namespace}/#{resource_type}/#{resource_name}?timeoutSeconds=#{timeout}"
end
