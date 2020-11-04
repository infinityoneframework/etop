defmodule Etop.WatcherTest do
  use ExUnit.Case

  import ExUnit.{CaptureIO, CaptureLog}

  alias Etop.WatcherTest.WatcherServer, as: Server

  setup meta do
    Application.put_env(:etop, :etop, Etop)
    etop_opts = Keyword.merge([first_interval: 10, interval: 50], meta[:etop_opts] || [])

    opts =
      meta
      |> Map.get(:opts, [])
      |> Keyword.put_new(:etop_opts, etop_opts)

    if Map.get(meta, :start, false), do: Server.start(opts)

    on_exit(fn ->
      if Server.alive?(), do: Server.stop()
      if Etop.alive?(), do: Etop.stop()
    end)

    :ok
  end

  def setup_state(meta) do
    {:ok, state: Server.initial_state(meta[:opts] || [])}
  end

  @tag :start
  test "get/0" do
    assert Server.get() == MapSet.new()
  end

  @tag :start
  test "put/1 and get/1" do
    Server.put(:test)
    Server.put({:a, 1})
    assert Server.get(:test)
    assert Server.get({:a, 1})
    refute Server.get({:a, 2})
  end

  @tag :start
  test "clear/1" do
    Server.put(:test)
    Server.put({:a, 1})
    assert Server.get(:test)
    assert Server.get({:a, 1})
    Server.clear(:test)
    refute Server.get(:test)
    assert Server.get({:a, 1})
  end

  @tag :start
  test "add_monitors" do
    Process.sleep(1)
    state = Server.initial_state()
    load_fn = Server.load_threshold(state)
    msgq_fn = Server.msgq_threshold(state)

    assert Etop.monitors() == [
             {:process, :message_queue_len, msgq_fn,
              {Etop.WatcherTest.WatcherServer, :message_queue_callback}},
             {:summary, [:load, :total], load_fn,
              {Etop.WatcherTest.WatcherServer, :load_callback}}
           ]
  end

  @tag etop_opts: [reporting: false]
  @tag opts: [notify_log: true, no_reporting: true]
  @tag :start
  test "trigger monitors" do
    refute Etop.status().reporting

    capture_io(fn ->
      logs =
        capture_log(fn ->
          Etop.Utils.create_load()
          Process.sleep(200)
        end)
        |> String.split("\n", trim: true)
        |> Enum.filter(&(&1 =~ "[info]"))
        |> Enum.take(3)

      assert length(logs) == 1
      assert Enum.all?(logs, &(&1 =~ "Etop high CPU usage:"))
    end)
  end

  test "custom opts" do
    {:ok, _} = Server.start(custom: "one", another: %{test: true})
    %{custom: custom, another: another} = Server.status()
    assert custom == "one"
    assert another == %{test: true}
  end

  describe "notify" do
    setup [:setup_state]

    @tag opts: [notify_log: true]
    test "notify_disable/3", %{state: state} do
      assert capture_log(fn ->
               assert Server.notify_disable(state, :test, "test message").set == MapSet.new()
             end) == ""

      assert capture_log(fn ->
               state = update_in(state, [:set], &MapSet.put(&1, :test))
               assert Server.notify_disable(state, :test, "test message").set == MapSet.new()
             end) =~ "test message"
    end
  end

  describe "handle_call :load_callback" do
    setup [:setup_state]

    @tag opts: [notify_log: true]
    test ">= enable_limit", %{state: state} do
      assert capture_log(fn ->
               etop = %{reporting: false}

               {:reply, reply, _} =
                 nil |> load_callback_params(90, etop) |> Server.handle_call(:dc, state)

               assert reply.reporting
             end) =~ "Etop high CPU usage: 90"
    end

    @tag opts: [notify_log: true]
    test "<= notify_lower_limit", %{state: state} do
      orig_state = state
      state = update_in(state, [:set], &MapSet.put(&1, :load))

      assert capture_log(fn ->
               etop = %{reporting: true}

               {:reply, reply, state1} =
                 nil |> load_callback_params(49, etop) |> Server.handle_call(:dc, state)

               assert reply.reporting
               refute MapSet.member?(state1.set, :load)
             end) =~ "Etop high CPU usage resolved: 49"

      assert capture_log(fn ->
               etop = %{reporting: true}

               {:reply, reply, state1} =
                 nil |> load_callback_params(49, etop) |> Server.handle_call(:dc, orig_state)

               assert reply.reporting
               assert state1 == orig_state
             end) == ""
    end

    @tag opts: [notify_log: true]
    test "<= disable_limit", %{state: state} do
      orig_state = state
      state = update_in(state, [:set], &MapSet.put(&1, :load))

      assert capture_log(fn ->
               etop = %{reporting: true}

               {:reply, reply, state1} =
                 nil |> load_callback_params(9, etop) |> Server.handle_call(:dc, state)

               refute reply.reporting
               refute MapSet.member?(state1.set, :load)
             end) =~ "Etop high CPU usage resolved: 9"

      assert capture_log(fn ->
               etop = %{reporting: true}

               {:reply, reply, state1} =
                 nil |> load_callback_params(9, etop) |> Server.handle_call(:dc, orig_state)

               refute reply.reporting
               assert state1 == orig_state
             end) == ""
    end

    @tag opts: [notify_log: true]
    test "default", %{state: state} do
      assert capture_log(fn ->
               etop = %{reporting: false}

               {:reply, reply, state1} =
                 nil |> load_callback_params(60, etop) |> Server.handle_call(:dc, state)

               assert reply == etop
               assert state1 == state
             end) == ""

      assert capture_log(fn ->
               etop = %{reporting: true}

               {:reply, reply, state1} =
                 nil |> load_callback_params(60, etop) |> Server.handle_call(:dc, state)

               assert reply == etop
               assert state1 == state
             end) == ""

      assert capture_log(fn ->
               etop = %{reporting: true}

               {:reply, reply, state1} =
                 :dc |> load_callback_params(10.0, etop) |> Server.handle_call(:dc, state)

               refute reply.reporting
               assert state1 == state
             end) == ""

      assert capture_log(fn ->
               etop = %{reporting: false}

               {:reply, reply, state1} =
                 :dc |> load_callback_params(10.0, etop) |> Server.handle_call(:dc, state)

               refute reply.reporting
               assert state1 == state
             end) == ""
    end
  end

  describe "handle_call :message_queue_callback" do
    setup [:setup_state]

    @tag opts: [notify_log: true]
    test ">= stop_limit", %{state: state} do
      pid = start()

      assert capture_log(fn ->
               etop = %{reporting: false}

               {:reply, reply, _} =
                 %{pid: pid}
                 |> queue_callback_params(20_000, etop)
                 |> Server.handle_call(:dc, state)

               refute reply.reporting
             end) =~ "Killing process with high msg_q length: 20000, pid: #{inspect(pid)}"

      refute Process.alive?(pid)
    end

    @tag opts: [notify_log: true]
    test ">= notify_limit", %{state: state} do
      pid = start()

      assert capture_log(fn ->
               etop = %{reporting: false}

               {:reply, reply, state1} =
                 %{pid: pid}
                 |> queue_callback_params(2000, etop)
                 |> Server.handle_call(:dc, state)

               assert reply.reporting
               assert MapSet.member?(state1.set, {:msgq, pid})
             end) =~ "High message queue length: 2000, pid: #{inspect(pid)}"

      assert Process.alive?(pid)

      pid = start()

      assert capture_log(fn ->
               etop = %{reporting: true}
               state = update_in(state, [:set], &MapSet.put(&1, {:msgq, pid}))

               {:reply, reply, state1} =
                 %{pid: pid}
                 |> queue_callback_params(2000, etop)
                 |> Server.handle_call(:dc, state)

               assert reply.reporting
               assert state1 == state
             end) == ""

      assert Process.alive?(pid)
    end

    @tag opts: [notify_log: true]
    test "< notify_limit", %{state: state} do
      pid = start()

      assert capture_log(fn ->
               etop = %{reporting: false}

               {:reply, reply, state1} =
                 %{pid: pid}
                 |> queue_callback_params(1000, etop)
                 |> Server.handle_call(:dc, state)

               refute reply.reporting
               refute MapSet.member?(state1.set, {:msgq, pid})
             end) == ""

      assert capture_log(fn ->
               etop = %{reporting: false, proc_r: MapSet.new([pid])}

               {:reply, reply, state1} =
                 %{pid: pid}
                 |> queue_callback_params(1000, etop)
                 |> Server.handle_call(:dc, %{state | set: MapSet.new([{:msgq, pid}])})

               refute reply.reporting
               refute reply[:proc_r]
               refute MapSet.member?(state1.set, {:msgq, pid})
             end) =~ "High Message queue alert resolved, pid: #{inspect(pid)}"
    end
  end

  defp load_callback_params(info, value, etop),
    do: {:load_callback, info, value, etop}

  defp queue_callback_params(info, value, etop),
    do: {:message_queue_callback, info, value, etop}

  defp start,
    do:
      spawn(fn ->
        receive do
          :quit -> :ok
        after
          1000 -> :ok
        end
      end)

  defmodule WatcherServer do
    use Etop.Watcher
  end
end
