defmodule Etop.MonitorTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Etop.Monitor

  setup do
    {:ok, state} = Etop.init([])
    stats2 = stats2()
    {:ok,
      state: %{state | stats: stats1()},
      monitor: cpu_monitor(),
      params: {stats2, stats2.procs}}
  end

  test "add_monitor", %{state: state, monitor: monitor} do
    assert Etop.add_monitor(state, :summary, [:load, :total], 10, monitor).monitors == [
      {:summary, [:load, :total], 10, monitor}
    ]
  end

  describe "summary" do
    test "no monitors", %{state: state, params: params} do
      assert Monitor.run(params, state) == {params, state}
    end

    test "no threshold", %{state: state, params: params, monitor: monitor} do
      state = Etop.add_monitor(state, :summary, [:load, :total], 20, monitor)
      assert Monitor.run(params, state) == {params, state}
      refute_received {:monitor, _, _}
    end

    test "monitor", %{state: state, monitor: monitor, params: params} do
      state = Etop.add_monitor(state, :summary, [:load, :total], 9, monitor)
      assert Monitor.run(params, state) == {params, %{state | reporting: false}}

      assert_received {:monitor, %{total: 12, user: 7}, 12}
    end

    test "does not return state", %{state: state, params: params} do
      pid = self()

      monitor = fn info, item, _state ->
        send pid, {:monitor, info, item}
        :ok
      end

      state = Etop.add_monitor(state, :summary, [:load, :total], 9, monitor)
      assert Monitor.run(params, state) == {params, state}

      assert_received {:monitor, %{total: 12, user: 7}, 12}
    end

    test "callback raises", %{state: state, params: params} do
      assert capture_log(fn ->
        monitor = fn _info, _item, _state -> raise "oops" end
        state = Etop.add_monitor(state, :summary, [:load, :total], 9, monitor)
        assert Monitor.run(params, state) == {params, state}
      end) =~ "monitor callback exception"

      refute_received {:monitor, _, _}
    end
  end

  describe "process" do
    test "processes monitor no trigger", %{state: state, params: params, monitor: monitor} do
      state = Etop.add_monitor(state, :process, :msg_q, 100, monitor)
      assert Monitor.run(params, state) == {params, state}
      refute_received {:monitor, _, _}
    end

    test "processes monitor", %{state: state, params: params, monitor: monitor} do
      state = Etop.add_monitor(state, :process, :msg_q, 10, monitor)
      assert Monitor.run(params, state) == {params, %{state | reporting: false}}

      assert_received {:monitor, %{memory: 6, msg_q: 10, pid: pid}, 10}
      assert pid == pid3()
    end

    test "processes monitor 2", %{state: state, params: params, monitor: monitor} do
      state = Etop.add_monitor(state, :process, :memory, 6, monitor)
      assert Monitor.run(params, state) == {params, %{state | reporting: false}}

      assert_received {:monitor, %{memory: 10, msg_q: 0, pid: pid1}, 10}
      assert pid1 == pid1()

      assert_received {:monitor, %{memory: 6, msg_q: 10, pid: pid3}, 6}
      assert pid3 == pid3()
    end
  end

  defp cpu_monitor do
    pid = self()
    fn info, item, state ->
      send pid, {:monitor, info, item}
      %{state | reporting: false}
    end
  end

  defp pid(list), do: :erlang.list_to_pid(list)
  defp pid1, do: pid('<0.10.0>')
  defp pid2, do: pid('<0.11.0>')
  defp pid3, do: pid('<0.13.0>')

  defp stats1, do: %{
    test: 5,
    load: %{
      user: 5,
      total: 10,
    },
    memory: %{
      total: 100
    },
    procs: [
      {pid1(), %{memory: 10, msg_q: 0}},
      {pid2(), %{memory: 5, msg_q: 5}},
      {pid3(), %{memory: 6, msg_q: 10}},
    ]
  }

  defp stats2, do: %{
    test: 6,
    load: %{
      user: 7,
      total: 12,
    },
    memory: %{
      total: 110
    },
    procs: [
      {pid1(), %{memory: 12, msg_q: 0}},
      {pid2(), %{memory: 5, msg_q: 5}},
      {pid3(), %{memory: 7, msg_q: 12}},
    ]
  }
end
