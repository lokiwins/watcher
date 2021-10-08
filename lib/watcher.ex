defmodule Watcher do
  defmacro __using__(opts \\ []) do
    base = __MODULE__

    quote do
      @opts unquote(opts)
      @base unquote(base)
      use Connection
      require Logger
      alias Watcher.Api

      defstruct resource_version: nil, response: nil, buffer: "", namespace: nil, hpa_state: %{}, watch_path: nil

      @default_opts [
        recv_timeout: 310_000
      ]

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          restart: :permanent,
          shutdown: 500
        }
      end

      def start_link(_args) do
        Connection.start_link(__MODULE__, config(), name: __MODULE__)
      end

      def config do
        Application.get_env(@opts[:otp_app], __MODULE__, [])
        |> Keyword.merge(@opts)
      end

      def state, do: GenServer.call(__MODULE__, :state)

      @impl true
      def init(config) do
        # Setup Initial State
        namespace = Keyword.get(config, :namespace)
        api_endpoint = Keyword.get(config, :api_endpoint)
        api_version = Keyword.get(config, :api_version)
        resource_type = Keyword.get(config, :resource_type)
        timeout = Keyword.get(config, :timeout, 300)

        # Get list of HPAs
        path = generate_get_path(api_endpoint, api_version, namespace, resource_type, timeout)
        {:ok, response} = make_request(path, %__MODULE__{namespace: namespace})

        hpa_state = Map.get(response, :body)
        |> Jason.decode!()
        |> Map.get("items")
        |> Enum.reduce(%{}, fn hpa_spec, acc ->
          Map.put(acc, hpa_spec["metadata"]["name"], hpa_spec)
        end)


        # Start watch
        {:connect, :init, %__MODULE__{namespace: namespace, hpa_state: hpa_state, watch_path: generate_watch_path(api_endpoint, api_version, namespace, resource_type, timeout)}}
      end

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

      @impl true
      def disconnect(_, state) do
        {:backoff, 1000, state}
      end

      @impl true
      def handle_info(%HTTPoison.AsyncStatus{} = status, state) do
        case status do
          %{code: 200} -> Logger.info(inspect(status))
          %{code: _code} -> Logger.error(inspect(status))
        end
        next_response(state)
      end

      @impl true
      def handle_info(%HTTPoison.AsyncHeaders{} = headers, state) do
        Logger.info(inspect(headers))
        next_response(state)
      end

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

          hpa_state = state.hpa_state
          |> Map.put(event["object"]["metadata"]["name"], event["object"])

          Map.put(state, :resource_version, event["object"]["metadata"]["resourceVersion"])
          |> Map.put(:hpa_state, hpa_state)
        end

        next_response(state)
      end

      @impl true
      def handle_info(%HTTPoison.AsyncEnd{} = async_end, state) do
        Logger.info(inspect(async_end))
        {:disconnect, async_end, state}
      end

      @impl true
      def handle_call(:state, _, state) do
        {:reply, state.hpa_state, state}
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

      defp generate_get_path(api_endpoint, api_version, namespace, resource_type, timeout),
        do: "/apis/#{api_endpoint}/#{api_version}/namespaces/#{namespace}/#{resource_type}?timeoutSeconds=#{timeout}"
      defp generate_watch_path(api_endpoint, api_version, namespace, resource_type, timeout),
        do: "/apis/#{api_endpoint}/#{api_version}/watch/namespaces/#{namespace}/#{resource_type}?timeoutSeconds=#{timeout}"
    end
  end
end
