defmodule Cand.Socket do
  @moduledoc """
    TCP socket handler for socketcand endpoint.
  """
  use GenServer

  defmodule State do
    @moduledoc """
      * last_cmds: It is a record of the last configuration commands that will be 
                   resent in case of an unscheduled reconnection.
      * port: Socketcand deamon port, default => 29536.
      * host: Network Interface IP, default => {127, 0, 0, 1}.
      * socket: Socket PID.
    """

    # port: 
    # controlling_process: parent process

    defstruct last_cmds: [],
              port: 29536,
              host: {127, 0, 0, 1},
              socket: nil,
              socket_opts: []
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use GenServer, Keyword.drop(opts, [:configuration])
      @behaviour Cand.Socket

      def start_link(user_initial_params \\ []) do
        GenServer.start_link(__MODULE__, user_initial_params, unquote(opts))
      end

      @impl true
      def init(user_initial_params) do
        send(self(), :init)
        {:ok, user_initial_params}
      end

      @impl true
      def handle_info(:init, user_initial_params) do
        # Socket Terraform
        {:ok, cs_pid} = Cand.Socket.start_link()

        configuration = apply(__MODULE__, :configuration, [user_initial_params])
        cyclic_frames = apply(__MODULE__, :cyclic_frames, [user_initial_params])
        subscriptions = apply(__MODULE__, :subscriptions, [user_initial_params])

        # configutation = list()
        set_socket_connection(cs_pid, configuration)
        set_socket_bus(cs_pid, configuration)

        # monitored_tiems = [subscription: 100.3, monitored_item: %MonitoredItem{}, ...]
        set_cyclic_frames(cs_pid, cyclic_frames)
        set_subscriptions(cs_pid, subscriptions)

        # User initialization.
        user_state = apply(__MODULE__, :init, [user_initial_params, cs_pid])

        {:noreply, user_state}
      end

      def handle_info({:frame, _can_id, _timestamp, _frame} = new_frame, state) do
        state = apply(__MODULE__, :handle_frame, [new_frame, state])
        {:noreply, state}
      end

      @impl true
      def handle_frame(new_frame_data, state) do
        require Logger

        Logger.warn(
          "No handle_frame/3 clause in #{__MODULE__} provided for #{inspect(new_frame_data)}"
        )

        state
      end

      @impl true
      def configuration(_user_init_state), do: []

      @impl true
      def cyclic_frames(_user_init_state), do: []

      @impl true
      def subscriptions(_user_init_state), do: []

      defp set_socket_connection(_cs_pid, nil), do: :ok

      defp set_socket_connection(cs_pid, configuration) do
        with host <- Keyword.get(configuration, :host, {127, 0, 0, 1}),
             true <- is_tuple(host),
             {:ok, ip_host} <- ip_to_tuple(host),
             port <- Keyword.get(configuration, :port, 29536),
             true <- is_integer(port) do
          Socket.connect(pid, ip_host, port, active: true)
        else
          _ ->
            require Logger

            Logger.warn(
              "Invalid Socket Connection params: #{inspect(configuration)} provided by #{
                __MODULE__
              }"
            )
        end
      end

      defp set_socket_bus(_cs_pid, nil), do: :ok

      defp set_socket_bus(cs_pid, configuration) do
        with interface <- Keyword.get(configuration, :interface, nil),
             true <- is_binary(interface),
             :ok <- Cand.Protocol.open(cs_pid, interface),
             mode <- Keyword.get(configuration, :mode, :raw_mode),
             true <- mode in [:bcm_mode, :raw_mode, :control_mode, :iso_tp_mode],
             :ok <- apply(Cand.Protocol, mode, [cs_pid]) do
          :ok
        else
          _ ->
            require Logger

            Logger.warn(
              "Invalid Socket Bus params: #{inspect(configuration)} provided by #{__MODULE__}"
            )
        end
      end

      defp set_cyclic_frames(socket, cyclic_frames) do
        Enum.each(cyclic_frames, fn cyclic_frame_data ->
          apply(Cand.Protocol, :add_cyclic_frame, [socket] ++ cyclic_frame_data)
        end)
      end

      defp set_subscriptions(socket, subscriptions) do
        Enum.each(subscriptions, fn subscription_data ->
          apply(Cand.Protocol, :subscriptions, [socket] ++ subscriptions_data)
        end)
      end

      defguardp is_ipv4_octet(v) when v >= 0 and v <= 255

      @doc """
      Convert & Validates an IP address to a string.
      """
      defp ip_to_tuple({a, b, c, d} = ipa)
           when is_ipv4_octet(a) and is_ipv4_octet(b) and is_ipv4_octet(c) and is_ipv4_octet(d),
           do: {:ok, ipa}

      defp ip_to_tuple(ipa) when is_binary(ipa) do
        ipa_charlist = to_charlist(ipa)

        case :inet.parse_address(ipa_charlist) do
          {:ok, addr} -> {:ok, addr}
          {:error, :einval} -> {:error, "Invalid IP address: #{ipa}"}
        end
      end

      defp ip_to_tuple(ipa), do: {:error, "Invalid IP address: #{inspect(ipa)}"}

      defoverridable start_link: 0,
                     start_link: 1,
                     configuration: 1,
                     cyclic_frames: 1,
                     subscriptions: 1,
                     handle_frame: 2
    end
  end

  def init(state), do: {:ok, state}

  def start_link do
    GenServer.start_link(__MODULE__, @initial_state)
  end

  def connect(pid, host, port, opts \\ []) do
    GenServer.call(pid, {:connect, host, port, opts})
  end

  def send(pid, msg) do
    GenServer.call(pid, {:send, msg})
  end

  def handle_call({:connect, host, port, opts}, _from_, state) do
    {:ok, socket} = :gen_tcp.connect(host, port, opts)
    {:reply, {:ok, host: host, port: port, opts: opts}, %{state | socket: socket, listener: nil}}
  end

  def handle_call({:send, msg}, _from_, %{socket: socket} = state) do
    with :ok <- :gen_tcp.send(socket, msg) do
      IO.inspect(msg, label: "CANBUS")
      {:reply, :ok, state}
    else
      _ ->
        {:reply, :error, state}
    end
  end

  def handle_call({:send_receive, msg}, _from_, %{socket: socket} = state) do
    :ok = :gen_tcp.send(socket, msg)
    {:ok, response} = :gen_tcp.recv(socket, 0)
    {:reply, response, state}
  end

  def handle_info({:tcp, _, message}, state) do
    IO.inspect(message, label: "CANBUS")

    message
    |> List.to_string()
    |> parse_messages
    |> Enum.map(fn message ->
      IO.inspect(message)
    end)

    {:noreply, state}
  end

  def handle_info({:tcp_closed, port}, state) do
    IO.inspect({:socket_closed, port})
    {:noreply, state}
  end

  defp parse_messages(messages) do
    messages
    |> String.split("><")
    |> Enum.map(fn frame ->
      frame
      |> String.trim("<")
      |> String.trim(">")
      |> String.trim()
      |> parse_message
    end)
  end

  defp parse_message("ok"), do: :ok
  defp parse_message("hi"), do: :ok
  defp parse_message("frame " <> frame), do: frame
  defp parse_message("error " <> message), do: {:error, message}
  defp parse_message(message), do: {:error, message}
end
