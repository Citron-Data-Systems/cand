defmodule Cand.Protocol do
  @moduledoc """
  Socketcand provides a network interface to a number of CAN busses on the host. 
  The used protocol is ASCII based and has some states in which different commands may be used.
  For more information check the following reference:
    * [SocketCand protocol](https://github.com/linux-can/socketcand/blob/master/doc/protocol.md)
  """
  alias Cand.Socket

  @flags_masks [
    listen_mode: 0x001,   # listen only (do not send FC).
    extend_addr: 0x002,   # enable extended addressing.
    tx_padding: 0x004,   # enable CAN frame padding tx path.
    rx_padding: 0x008,   # enable CAN frame padding rx path.
    chk_pad_len: 0x010,   # check received CAN frame padding.
    chk_pad_data: 0x020,   # check received CAN frame padding.
    half_duplex: 0x040,   # half duplex error state handling.
    force_txstmin: 0x080,   # ignore stmin from received FC.
    force_rxstmin: 0x100,   # ignore CFs depending on rx stmin.
    rx_ext_addr: 0x200,   # different rx extended addressing.
  ]

  defguardp is_a_integer_greater_or_equal_than?(value, less_or_equal_than) when is_integer(value) and value >= less_or_equal_than

  ## Mode NO_BUS ##

  # The Mode NO_BUS is the only mode where bittimings or other bus configuration settings may be done.

  @doc """
  The open command is used to select one of the CAN busses.
  Note: The can_device may be at maximum 16 characters long.
  """
  @spec open(GenServer.server(), binary()) :: :ok | {:error, atom()}
  def open(socket, can_device) when is_pid(socket) and is_binary(can_device) do
    with  str_size <- String.length(can_device),
          true <- str_size <= 16 do
      Socket.send(socket, "< open #{can_device} >")
    else
      _ ->
        raise(ArgumentError, "The can_device may be at maximum 16 characters long")
    end
  end

  ## Mode BCM (Broadcast Manager) ##

  ### Commands for transmission ###

  @doc """
  Add a new frame (job) for transmission. This command adds a new frame to the BCM queue.
  An interval can be configured to have the frame sent cyclic.
  """
  @spec add_cyclic_frame(GenServer.server(), integer(), binary(), integer(), integer()) :: :ok | {:error, atom()}
  def add_cyclic_frame(socket, can_id, frame, secs \\ 0, u_secs \\ 10) do
    with  true <- is_pid(socket),
          true <- is_a_integer_greater_or_equal_than?(can_id, 0),
          true <- is_a_integer_greater_or_equal_than?(secs, 0),
          true <- is_a_integer_greater_or_equal_than?(u_secs, 0),
          true <- is_binary(frame),
          can_dlc <- byte_size(frame),
          str_frame <- frame_binary_to_string(frame) do
      Socket.send(socket, "< add #{secs} #{u_secs} #{can_id} #{can_dlc} #{str_frame}>")
    else
      _ ->
        raise(ArgumentError, "There is an invalid Argument.")
    end
  end

  @doc """
  This functions updates a frame transmission job that was created via the `add/3`
  command with new content.
  NOTE: The transmission timers are not touched.
  """
  @spec update_cyclic_frame(GenServer.server(), integer(), binary()) :: :ok | {:error, atom()}
  def update_cyclic_frame(socket, can_id, frame) do
    with  true <- is_pid(socket),
          true <- is_a_integer_greater_or_equal_than?(can_id, 0),
          true <- is_binary(frame),
          can_dlc <- byte_size(frame),
          str_frame <- frame_binary_to_string(frame) do
      Socket.send(socket, "< update #{can_id} #{can_dlc} #{str_frame}>")
    else
      _ ->
        raise(ArgumentError, "There is an invalid Argument.")
    end
  end

  @doc """
  Deletes a the cyclic frame transmission job.
  """
  @spec delete_cyclic_frame(GenServer.server(), integer()) :: :ok | {:error, atom()}
  def delete_cyclic_frame(socket, can_id) do
    with  true <- is_pid(socket),
          true <- is_a_integer_greater_or_equal_than?(can_id, 0) do
      Socket.send(socket, "< delete #{can_id} >")
    else
      _ ->
        raise(ArgumentError, "There is an invalid Argument.")
    end
  end

  @doc """
  Sends a single CAN frame.
  """
  @spec send_frame(GenServer.server(), integer(), binary()) :: :ok | {:error, atom()}
  def send_frame(socket, can_id, frame) do
    with  true <- is_pid(socket),
          true <- is_a_integer_greater_or_equal_than?(can_id, 0),
          true <- is_binary(frame),
          can_dlc <- byte_size(frame),
          str_frame <- frame_binary_to_string(frame) do
      Socket.send(socket, "< send #{can_id} #{can_dlc} #{str_frame}>")
    else
      _ ->
        raise(ArgumentError, "There is an invalid Argument.")
    end
  end

  ### Commands for reception ###

  @doc """
  This command is used to configure the broadcast manager for reception of frames with a given CAN ID. 
  Frames are only received when they match the pattern that is provided. 
  The time value given is used to throttle the incoming update rate.
  """
  @spec filter_frames(GenServer.server(), integer(), binary(), integer(), integer()) :: :ok | {:error, atom()}
  def filter_frames(socket, can_id, pattern, secs \\ 0, u_secs \\ 10) do
    with  true <- is_pid(socket),
          true <- is_a_integer_greater_or_equal_than?(can_id, 0),
          true <- is_a_integer_greater_or_equal_than?(secs, 0),
          true <- is_a_integer_greater_or_equal_than?(u_secs, 0),
          true <- is_binary(pattern),
          can_dlc <- byte_size(pattern),
          str_pattern <- pattern_binary_to_string(pattern) do
      Socket.send(socket, "< filter #{secs} #{u_secs} #{can_id} #{can_dlc} #{str_pattern}>")
    else
      _ ->
        raise(ArgumentError, "There is an invalid Argument.")
    end
  end

  @doc """
  This command is used to configure the broadcast manager for reception of frames 
  with a given CAN ID and a multiplex message filter mask. 
  Frames are only sent when they match the pattern that is provided. 
  The time value given is used to throttle the incoming update rate.
  NOTE: Pattern size must be n_frame * 8.
  """
  @spec filter_multiplex_frames(GenServer.server(), integer(), integer(), binary(), integer(), integer()) :: :ok | {:error, atom()}
  def filter_multiplex_frames(socket, can_id, n_frame, pattern, secs \\ 0, u_secs \\ 10) do
    with  true <- is_pid(socket),
          true <- is_a_integer_greater_or_equal_than?(can_id, 0),
          true <- is_a_integer_greater_or_equal_than?(n_frame, 0),
          true <- is_a_integer_greater_or_equal_than?(secs, 0),
          true <- is_a_integer_greater_or_equal_than?(u_secs, 0),
          true <- is_binary(pattern),
          can_dlc <- byte_size(pattern),
          true <- can_dlc == n_frame * 8,
          str_pattern <- pattern_binary_to_string(pattern) do
      Socket.send(socket, "< muxfilter #{secs} #{u_secs} #{can_id} #{n_frame} #{str_pattern}>")
    else
      _ ->
        raise(ArgumentError, "There is an invalid Argument.")
    end
  end

  @doc """
  Adds a subscription to a CAN ID. The frames are sent regardless of their content. 
  An interval in seconds or microseconds may be set.
  """
  @spec subscribe(GenServer.server(), integer(), integer(), integer()) :: :ok | {:error, atom()}
  def subscribe(socket, can_id, secs \\ 0, u_secs \\ 10) do
    with  true <- is_pid(socket),
          true <- is_a_integer_greater_or_equal_than?(can_id, 0),
          true <- is_a_integer_greater_or_equal_than?(secs, 0),
          true <- is_a_integer_greater_or_equal_than?(u_secs, 0) do
      Socket.send(socket, "< subscribe #{secs} #{u_secs} #{can_id} >")
    else
      _ ->
        raise(ArgumentError, "There is an invalid Argument.")
    end
  end

  @doc """
  Deletes all subscriptions or filters for a specific CAN ID.
  """
  @spec unsubscribe(GenServer.server(), integer()) :: :ok | {:error, atom()}
  def unsubscribe(socket, can_id) do
    with  true <- is_pid(socket),
          true <- is_a_integer_greater_or_equal_than?(can_id, 0) do
      Socket.send(socket, "< unsubscribe #{can_id} >")
    else
      _ ->
        raise(ArgumentError, "There is an invalid Argument.")
    end
  end

  ## Mode CONTROL ##

  @doc """
  In CONTROL mode it is possible to receive bus statistics at a certain interval in milliseconds. 
  """
  @spec statistics(GenServer.server(), integer()) :: :ok | {:error, atom()}
  def statistics(socket, interval) do
    with  true <- is_pid(socket),
          true <- is_a_integer_greater_or_equal_than?(interval, 0) do
      Socket.send(socket, "< statistics #{interval} >")
    else
      _ ->
        raise(ArgumentError, "There is an invalid Argument.")
    end
  end

  ## Mode ISO-TP ##

  @doc """
  Configures the ISO-TP channel. The following options are supported:
    * `tx_id` - CAN ID of channel to transmit data (from the host / src). CAN IDs 000h up to 7FFh (standard frame format) and 00000000h up to 1FFFFFFFh (extended frame format).
    * `rx_id` - CAN ID of channel to receive data (to the host / dst). CAN IDs in same format as tx_id.
    * `flags` - hex value built from the original flags from isotp.h. These flags define which of the following parameters is used/required in which way.
    * `blocksize` - can take values from 0 (=off) to 15
    * `stmin` - separation time minimum. Hex value from 00h - FFh according to ISO-TP specification
    * `wftmax` - maximum number of wait frames (0 = off)
    * `txpad_content` - padding value in the tx path.
    * `rxpad_content` - padding value in the rx path.
    * `ext_address` - extended adressing feature (value for tx and rx if not specified separately / enable CAN_ISOTP_EXTEND_ADDR in flags)
    * `rx_ext_address` - extended adressing feature (separate value for rx / enable CAN_ISOTP_RX_EXT_ADDR in flags)
  """
  @spec iso_tp_conf(GenServer.server(), list()) :: :ok | {:error, atom()}
  def iso_tp_conf(socket, isotp_params) do
    with  true <- is_pid(socket),
          tx_id <- Keyword.fetch!(isotp_params, :tx_id),
          true <- is_between_or_nil?(tx_id, 0x00000000, 0x1FFFFFFF),
          tx_id <- integer_to_string(tx_id),
          rx_id <- Keyword.fetch!(isotp_params, :rx_id),
          true <- is_between_or_nil?(rx_id, 0x00000000, 0x1FFFFFFF),
          rx_id <- integer_to_string(rx_id),
          flags_int <- Keyword.fetch!(isotp_params, :flags),
          true <- is_between_or_nil?(flags_int, 0x000, 0x3FF),
          flags <- integer_to_string(flags_int),
          blocksize <- Keyword.fetch!(isotp_params, :blocksize),
          true <- is_between_or_nil?(blocksize, 0x00, 0x0F),
          blocksize <- integer_to_string(blocksize),
          stmin <- Keyword.fetch!(isotp_params, :stmin),
          true <- is_between_or_nil?(stmin, 0x00, 0xFF),
          stmin <- integer_to_string(stmin),
          wftmax <- Keyword.get(isotp_params, :wftmax, 0),
          true <- wftmax >= 0,
          wftmax <- integer_to_string(wftmax),
          txpad_content <- Keyword.get(isotp_params, :txpad_content, nil),
          true <- is_param_enabled_or_nil?(txpad_content, flags_int, @flags_masks[:tx_padding]),
          txpad_content <- integer_to_string(txpad_content),
          rxpad_content <- Keyword.get(isotp_params, :rxpad_content, nil),
          true <- is_param_enabled_or_nil?(rxpad_content, flags_int, @flags_masks[:rx_padding]),
          rxpad_content <- integer_to_string(rxpad_content),
          ext_address <- Keyword.get(isotp_params, :ext_address, nil),
          true <- is_param_enabled_or_nil?(ext_address, flags_int, @flags_masks[:extend_addr]),
          ext_address <- integer_to_string(ext_address),
          rx_ext_address <- Keyword.get(isotp_params, :rx_ext_address, nil),
          true <- is_param_enabled_or_nil?(rx_ext_address, flags_int, @flags_masks[:rx_ext_addr]),
          rx_ext_address <- integer_to_string(rx_ext_address) do
      Socket.send(socket, "< isotpconf #{tx_id} #{rx_id} #{flags} #{blocksize} #{stmin} #{wftmax} #{txpad_content} #{rxpad_content} #{ext_address} #{rx_ext_address} >")
    else
      _ ->
        raise(ArgumentError, "There is an invalid Argument.")
    end
  end

  defp integer_to_string(nil), do: nil
  defp integer_to_string(value), do: Integer.to_string(value, 16)

  defp is_between_or_nil?(nil, _greater_or_equal_than, _less_or_equal_than), do: true
  defp is_between_or_nil?(value, greater_or_equal_than, less_or_equal_than), 
    do: value >= greater_or_equal_than and value <= less_or_equal_than

  defp is_param_enabled_or_nil?(nil, _flags_int, _mask), do: true
  defp is_param_enabled_or_nil?(_value, flags_int, mask), 
    do: if Bitwise.band(flags_int, mask) > 0, do: true, else: false

  @doc """
  Sends a protocol data unit (PDU), only for ISO-TP mode. 
  """
  @spec send_pdu(GenServer.server(), binary()) :: :ok | {:error, atom()}
  def send_pdu(socket, pdu) do
    with  true <- is_pid(socket),
          true <- is_binary(pdu),
          str_pdu <- frame_binary_to_string(pdu) do
      Socket.send(socket, "< sendpdu #{str_pdu}>")
    else
      _ ->
        raise(ArgumentError, "There is an invalid Argument.")
    end
  end

  ## Modes ##

  @doc """
  In this mode a BCM socket to the bus will be opened and can be controlled over the connection. 
  The following commands are understood:
    * add_cyclic_frame
    * update_cyclic_frame
    * delete_cyclic_frame
    * send_frame
    * filter_frames
    * filter_multiplex_frames
    * subscribe
    * unsubscribe
  """
  @spec bcm_mode(GenServer.server()) :: :ok | {:error, atom()}
  def bcm_mode(socket) do
    Socket.send(socket, "< bcmmode >")
  end

  @doc """
  In RAW mode every frame on the bus will immediately be received. 
  Only the send command works as in BCM mode. The following commands are understood:
    * send_frame
  """
  @spec raw_mode(GenServer.server()) :: :ok | {:error, atom()}
  def raw_mode(socket) do
    Socket.send(socket, "< rawmode >")  
  end

  @doc """
  In CONTROL mode it is possible to receive bus statistics. 
  The following commands are understood:
    * statistics.
  """
  @spec control_mode(GenServer.server()) :: :ok | {:error, atom()}
  def control_mode(socket) do
    Socket.send(socket, "< controlmode >")  
  end

  @doc """
  A transport protocol, such as ISO-TP, is needed to enable e.g. software updload via CAN. 
  It organises the connection-less transmission of a sequence of data. 
  An ISO-TP channel consists of two exclusive CAN IDs, one to transmit data and the other to receive data.
  After configuration a single ISO-TP channel can be used. 
  The ISO-TP mode can be used exclusively like the other modes (bcmmode, rawmode, isotpmode).
  The following commands are understood:
    * iso_tp_config.
    * send_pdu.
  """
  def iso_tp_mode(socket) do
    Socket.send(socket, "< isotpmode >")  
  end

  ## Misc ##

  @doc """
  After the server receives an '< echo >' it immediately returns the same string. 
  This can be used to see if the connection is still up and to measure latencies.
  """
  @spec echo(GenServer.server()) :: {:ok, map()} | {:error, :einval}
  def echo(socket) when is_pid(socket) do
    Socket.send_receive(socket, "< echo >")
  end

  defp pattern_binary_to_string(pattern_frame), do: frame_binary_to_string(pattern_frame)
  defp frame_binary_to_string(frame) do
    for <<byte::8 <- frame >>, reduce: "" do
      acc -> acc <> Integer.to_string(byte, 16) <> " "
    end
  end
end
