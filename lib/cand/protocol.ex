defmodule Cand.Protocol do
  @moduledoc """
  Socketcand provides a network interface to a number of CAN busses on the host. 
  The used protocol is ASCII based and has some states in which different commands may be used.
  For more information check the following reference:
    * [SocketCand protocol](https://github.com/linux-can/socketcand/blob/master/doc/protocol.md)
  """
  alias Cand.Socket

  defguardp is_a_integer_greater_or_equal_than(value, less_or_equal_than) when is_integer(value) and value >= less_or_equal_than

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
          true <- is_a_integer_greater_or_equal_than(can_id, 0),
          true <- is_a_integer_greater_or_equal_than(secs, 0),
          true <- is_a_integer_greater_or_equal_than(u_secs, 0),
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
          true <- is_a_integer_greater_or_equal_than(can_id, 0),
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
          true <- is_a_integer_greater_or_equal_than(can_id, 0) do
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
          true <- is_a_integer_greater_or_equal_than(can_id, 0),
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
          true <- is_a_integer_greater_or_equal_than(can_id, 0),
          true <- is_a_integer_greater_or_equal_than(secs, 0),
          true <- is_a_integer_greater_or_equal_than(u_secs, 0),
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
          true <- is_a_integer_greater_or_equal_than(can_id, 0),
          true <- is_a_integer_greater_or_equal_than(n_frame, 0),
          true <- is_a_integer_greater_or_equal_than(secs, 0),
          true <- is_a_integer_greater_or_equal_than(u_secs, 0),
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
          true <- is_a_integer_greater_or_equal_than(can_id, 0),
          true <- is_a_integer_greater_or_equal_than(secs, 0),
          true <- is_a_integer_greater_or_equal_than(u_secs, 0) do
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
          true <- is_a_integer_greater_or_equal_than(can_id, 0) do
      Socket.send(socket, "< unsubscribe #{can_id} >")
    else
      _ ->
        raise(ArgumentError, "There is an invalid Argument.")
    end
  end

  ## Mode ##

  def bcmmode(socket) do
    Socket.send(socket, "< bcmmode >")
  end

  def rawmode(socket) do
    Socket.send(socket, "< rawmode >")  
  end

  def controlmode(socket) do
    Socket.send(socket, "< controlmode >")  
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
