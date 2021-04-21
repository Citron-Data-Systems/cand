defmodule PassiveSocketTest do
  use ExUnit.Case

  @seed :rand.uniform(1000)

  setup_all do
    socketcand_exec = System.find_executable("socketcand")
    port = 28600 + @seed
    socketcand_params = ["-v", "-ivcan0", "-p#{port}", "-llo", "-n", "-d"]
    muontrap_params = [
      stderr_to_stdout: true,
      log_output: :debug,
      log_prefix: "(#{__MODULE__}) "
    ]

    {:ok, m_pid} = MuonTrap.Daemon.start_link(socketcand_exec, socketcand_params, muontrap_params)

    Process.sleep(1000)

    {:ok, %{port: port, m_pid: m_pid}}
  end
  
  test "Socket connection (Passive mode)", state do
    {:ok, pid} = Cand.Socket.start_link()
    assert :hi == Cand.Socket.connect(pid, {127,0,0,1}, state.port)
    assert :ok == Cand.Socket.disconnect(pid)
  end

  test "Open CAN bus (Passive mode)", state do
    {:ok, pid} = Cand.Socket.start_link()
    assert :hi == Cand.Socket.connect(pid, {127,0,0,1}, state.port)

    assert [error: "could not open bus"] == Cand.Protocol.open(pid, "vcan1")
    assert {:error, :closed} == Cand.Protocol.open(pid, "vcan0")
    assert :hi == Cand.Socket.connect(pid, {127,0,0,1}, state.port)
    assert [:ok] == Cand.Protocol.open(pid, "vcan0")

    assert :ok == Cand.Socket.disconnect(pid)
  end

  test "Raw Mode CAN bus between 2 devices (Passive mode)", state do
    {:ok, d1_pid} = Cand.Socket.start_link()
    {:ok, d2_pid} = Cand.Socket.start_link()

    assert :hi == Cand.Socket.connect(d1_pid, {127,0,0,1}, state.port)
    assert :hi == Cand.Socket.connect(d2_pid, {127,0,0,1}, state.port)

    assert [:ok] == Cand.Protocol.open(d1_pid, "vcan0")
    assert [:ok] == Cand.Protocol.open(d2_pid, "vcan0")

    assert [:ok] == Cand.Protocol.raw_mode(d1_pid)
    assert [:ok] == Cand.Protocol.raw_mode(d2_pid)

    assert [:ok] == Cand.Protocol.send_frame(d1_pid, 0x123, <<103, 103, 103>>)
    [{:frame, {291, _timestamp, "ggg"}}] = Cand.Protocol.receive_frame(d2_pid)

    assert [:ok] == Cand.Protocol.send_frame(d2_pid, 0x103, <<123, 123, 123>>)
    [{:frame, {259, _timestamp, "{{{"}}] = Cand.Protocol.receive_frame(d1_pid)

    assert :ok == Cand.Socket.disconnect(d1_pid)
    assert :ok == Cand.Socket.disconnect(d2_pid)
  end
end
