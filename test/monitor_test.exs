defmodule Etop.MonitorTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Etop.Monitor

  defmodule Callbacks do
    require Logger

    def callback(a, b, state) do
      Logger.info("callback called #{inspect(a)}, #{inspect(b)}")
      %{state | reporting: false}
    end
  end

  setup do
    {:ok, state} = Etop.init([])
    stats2 = stats2()

    {:ok,
     state: %{state | stats: stats1()}, monitor: cpu_monitor(), params: {stats2, stats2.procs}}
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
        send(pid, {:monitor, info, item})
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

    test "run mf callback", %{state: state, params: params} do
      state = Etop.add_monitor(state, :summary, [:load, :total], 9, {Callbacks, :callback})

      assert capture_log(fn ->
               assert Monitor.run(params, state) == {params, %{state | reporting: false}}
             end) =~ "callback called %{total: 12, user: 7}, 12"
    end

    test "threshould tuple", %{state: state, params: params, monitor: monitor} do
      state = Etop.add_monitor(state, :summary, [:load, :total], {&>=/2, 9}, monitor)
      assert Monitor.run(params, state) == {params, %{state | reporting: false}}

      assert_received {:monitor, %{total: 12, user: 7}, 12}
    end

    test "threshould tuple <", %{state: state, params: params, monitor: monitor} do
      state = Etop.add_monitor(state, :summary, [:load, :total], {&</2, 20}, monitor)
      assert Monitor.run(params, state) == {params, %{state | reporting: false}}

      assert_received {:monitor, %{total: 12, user: 7}, 12}
    end

    test "threshold fn/1", %{state: state, params: params, monitor: monitor} do
      state = Etop.add_monitor(state, :summary, [:load, :total], &(&1 >= 9), monitor)
      assert Monitor.run(params, state) == {params, %{state | reporting: false}}

      assert_received {:monitor, %{total: 12, user: 7}, 12}
    end

    test "threshold fn/2", %{state: state, params: params, monitor: monitor} do
      fun2 = &(&1.user < 8 and &2.reporting)

      state1 = %{state | reporting: false}

      state = Etop.add_monitor(state, :summary, [:load], fun2, monitor)
      assert Monitor.run(params, state) == {params, %{state | reporting: false}}

      assert_received {:monitor, %{total: 12, user: 7}, %{total: 12, user: 7}}

      state = Etop.add_monitor(state1, :summary, [:load], fun2, monitor)
      assert Monitor.run(params, state) == {params, state}

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

    test "processes monitor threshold/3 >= limit", %{
      state: state,
      params: params,
      monitor: monitor
    } do
      state = Etop.add_monitor(state, :process, :msg_q, msgq_threshold(10), monitor)
      assert Monitor.run(params, state) == {params, %{state | reporting: false}}

      assert_received {:monitor, %{memory: 6, msg_q: 10, pid: pid}, 10}
      assert pid == pid3()
    end

    test "processes monitor threshold/3 < limit", %{
      state: state,
      params: params,
      monitor: monitor
    } do
      threshold15 = msgq_threshold(15)
      orig_state = state

      state = Etop.add_monitor(state, :process, :msg_q, threshold15, monitor)
      assert Monitor.run(params, state) == {params, %{state | reporting: true}}

      refute_received {:monitor, _, _}

      pid = pid1()

      state = Map.put(orig_state, :proc_r, MapSet.new([pid]))
      state = Etop.add_monitor(state, :process, :msg_q, threshold15, monitor)
      assert Monitor.run(params, state) == {params, %{state | reporting: false}}

      assert_received {:monitor, %{memory: 10, msg_q: 0, pid: ^pid}, 0}
    end

    test "processes monitor threshold/3 >= limit 2", %{
      state: state,
      params: params,
      monitor: monitor
    } do
      state = Etop.add_monitor(state, :process, :msg_q, msgq_threshold(10), monitor)
      assert Monitor.run(params, state) == {params, %{state | reporting: false}}

      assert_received {:monitor, %{memory: 6, msg_q: 10, pid: pid}, 10}
      assert pid == pid3()
    end
  end

  test "threshold" do
    threshold4 = msgq_threshold(4)
    threshold10 = msgq_threshold(10)
    pid = pid1()

    refute threshold4.(3, %{pid: pid}, %{})
    assert threshold4.(4, %{pid: pid}, %{})

    assert threshold4.(3, %{pid: pid}, %{proc_r: MapSet.new([pid])})
    refute threshold4.(3, %{pid: pid}, %{proc_r: MapSet.new([pid2()])})

    refute threshold10.(3, %{pid: pid}, %{})
    assert threshold10.(12, %{pid: pid}, %{})
  end

  defp msgq_threshold(limit) do
    r_test = &(!!&1[:proc_r] and MapSet.member?(&1[:proc_r], &2[:pid]))
    &(&1 >= limit or r_test.(&3, &2))
  end

  defp cpu_monitor do
    pid = self()

    fn info, item, state ->
      send(pid, {:monitor, info, item})
      %{state | reporting: false}
    end
  end

  defp pid(list), do: :erlang.list_to_pid(list)
  defp pid1, do: pid('<0.10.0>')
  defp pid2, do: pid('<0.11.0>')
  defp pid3, do: pid('<0.13.0>')

  defp stats1,
    do: %{
      test: 5,
      load: %{
        user: 5,
        total: 10
      },
      memory: %{
        total: 100
      },
      procs: [
        {pid1(), %{memory: 10, msg_q: 0, pid: pid1()}},
        {pid2(), %{memory: 5, msg_q: 5, pid: pid2()}},
        {pid3(), %{memory: 6, msg_q: 10, pid: pid3()}}
      ]
    }

  defp stats2,
    do: %{
      test: 6,
      load: %{
        user: 7,
        total: 12
      },
      memory: %{
        total: 110
      },
      procs: [
        {pid1(), %{memory: 12, msg_q: 0, pid: pid1()}},
        {pid2(), %{memory: 5, msg_q: 5, pid: pid2()}},
        {pid3(), %{memory: 7, msg_q: 12, pid: pid3()}}
      ]
    }
end
