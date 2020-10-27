defmodule Etop.ReaderTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  alias Etop.{Fixtures, Reader}

  @default_memory %{
    atom: 512_625,
    atom_used: 497_567,
    binary: 591_216,
    code: 10_210_542,
    ets: 782_296,
    processes: 10_190_736,
    processes_used: 10_157_352,
    system: 20_638_752,
    total: 30_829_488
  }

  setup do
    {:ok, cores} = CpuUtil.core_count()
    os_pid = CpuUtil.getpid()
    util = {File.read!("/proc/stat"), File.read!("/proc/#{os_pid}/stat")}
    {:ok, state} = Etop.init(os_pid: os_pid, cores: cores, util: util)

    {:ok, state: state, stat1: Fixtures.proc_stat1(), stat2: Fixtures.proc_stat2()}
  end

  def setup_monitor(%{state: state} = meta) do
    procs1 = Fixtures.procs1()
    procs2 = Fixtures.procs2()
    opts = Keyword.merge([procs: procs1], meta[:init_stats] || [])
    {:ok, state: init_stats(state, opts), procs1: procs1, procs2: procs2}
  end

  test "remote_cpu_info/1 local", %{state: state} do
    Reader.remote_cpu_info(state)

    assert_receive {:cpu_info_result, info}

    %{
      cores: {:ok, cores},
      os_pid: os_pid,
      util: {{:ok, stat}, {:ok, proc_stat}}
    } = info

    assert cores == state.cores
    assert os_pid == state.os_pid
    assert is_binary(stat)
    assert is_binary(proc_stat)

    assert stat =~ ~r/^cpu\s+\d+/
    assert proc_stat =~ ~r/\d+\s+\(beam.smp\)/
  end

  test "remove_stats/1 local", %{state: state} do
    Reader.remote_stats(state)

    assert_receive {:result, stats}

    memory_keys = [
      :atom,
      :atom_used,
      :binary,
      :code,
      :ets,
      :processes,
      :processes_used,
      :system,
      :total
    ]

    %{
      memory: memory,
      nprocs: nprocs,
      procs: procs,
      runq: runq,
      util: {{:ok, stat}, {:ok, proc_stat}}
    } = stats

    assert nprocs =~ ~r/^\d+$/
    assert runq >= 0 and runq < 10
    assert stat =~ ~r/^cpu\s+\d+/
    assert proc_stat =~ ~r/\d+\s+\(beam.smp\)/
    assert memory |> Map.keys() |> Enum.sort() == memory_keys
    assert Enum.all?(memory, &(&1 |> elem(1) |> is_integer()))
    assert length(procs) in 90..110

    {_, proc} = hd(procs)
    {:memory, memory_val} = proc[:memory]
    assert is_integer(memory_val)
  end

  test "handle_connect/2", %{state: state} do
    stats = get_stats(state)

    state = Reader.handle_collect(state, stats)

    assert length(state.stats.processes) == 10

    assert state.stats.load |> Map.keys() |> Enum.sort() == ~w(sys total user)a
    assert state.stats.load |> Map.values() |> Enum.all?(&is_float/1)

    {a, b} = state.stats.util
    assert is_binary(a) and is_binary(b)
  end

  test "handle_connect/2 stats", %{state: state} do
    stats = get_stats(state)
    %{stats: %{load: load, total: total}} = Reader.handle_collect(state, stats)

    assert is_integer(total)
    %{total: total} = load
    assert is_float(total)
  end

  test "process_util pairs" do
    data = Fixtures.proc_stats()

    result =
      Enum.map(data, fn {prev, curr} ->
        CpuUtil.process_util(prev, curr, cores: 6)
      end)

    assert result == [
             %{sys: 1.0, total: 14.0, user: 13.0},
             %{sys: 1.0, total: 14.0, user: 13.0},
             %{sys: 1.0, total: 12.9, user: 11.9},
             %{sys: 0.0, total: 12.0, user: 12.0},
             %{sys: 0.0, total: 1.0, user: 1.0},
             %{sys: 0.0, total: 0.0, user: 0.0}
           ]
  end

  test "process_util continuous" do
    data = Fixtures.proc_stats()

    {prev, _} = hd(data)
    samples = Enum.map(data, &elem(&1, 1))

    {_, acc} =
      Enum.reduce(samples, {prev, []}, fn curr, {prev, acc} ->
        util = CpuUtil.process_util(prev, curr, cores: 6)
        {curr, [util | acc]}
      end)

    assert Enum.reverse(acc) == [
             %{sys: 1.0, total: 14.0, user: 13.0},
             %{sys: 1.0, total: 14.0, user: 13.0},
             %{sys: 1.0, total: 12.9, user: 11.9},
             %{sys: 0.0, total: 12.0, user: 12.0},
             %{sys: 0.0, total: 1.0, user: 1.0},
             %{sys: 0.0, total: 0.0, user: 0.0}
           ]
  end

  test "handle_connect/2 fixture", %{state: state} do
    stats = get_stats(state)
    data = Fixtures.proc_stats()

    {prev, _} = hd(data)
    samples = Enum.map(data, &elem(&1, 1))

    state = %{state | stats: %{state.stats | util: prev}}

    {_, acc} =
      Enum.reduce(samples, {state, []}, fn curr, {state, acc} ->
        state = %{stats: %{load: load}} = Reader.handle_collect(state, %{stats | util: curr})
        {state, [load | acc]}
      end)

    assert Enum.reverse(acc) == [
             %{sys: 1.0, total: 14.0, user: 13.0},
             %{sys: 1.0, total: 14.0, user: 13.0},
             %{sys: 1.0, total: 12.9, user: 11.9},
             %{sys: 0.0, total: 12.0, user: 12.0},
             %{sys: 0.0, total: 1.0, user: 1.0},
             %{sys: 0.0, total: 0.0, user: 0.0}
           ]
  end

  describe "monitor" do
    setup [:setup_monitor]

    test "monitor process", %{state: state, procs2: procs2} do
      self = self()

      callback = fn info, value ->
        send(self, {:exceeded, info.pid, value})
      end

      state
      |> Etop.monitor(:process, :message_queue_len, 10, callback)
      |> Reader.handle_collect(init_stats(state.stats, procs: procs2))

      assert_receive {:exceeded, pid, 12}
      assert is_pid(pid)

      refute_receive {:exceeded, _, _}
    end

    test "monitor process mf mode", %{state: state, procs2: procs2} do
      expected =
        inspect(
          %{
            current_function: {:prim_file, :helper_loop, 0},
            dictionary: [],
            error_handler: :error_handler,
            garbage_collection: [
              max_heap_size: %{error_logger: true, kill: true, size: 0},
              min_bin_vheap_size: 46422,
              min_heap_size: 233,
              fullsweep_after: 65535,
              minor_gcs: 0
            ],
            group_leader: :erlang.list_to_pid('<0.0.0>'),
            heap_size: 233,
            initial_call: {:prim_file, :start, 0},
            links: [],
            memory: {:memory, 2688},
            message_queue_len: 12,
            pid: :erlang.list_to_pid('<0.6.0>'),
            priority: :normal,
            reductions: 194,
            stack_size: 1,
            status: :waiting,
            suspending: [],
            total_heap_size: 233,
            trap_exit: false
          },
          pretty: true,
          limit: :infinity
        ) <> "\n"

      assert capture_io(fn ->
               state
               |> Etop.monitor(:process, :message_queue_len, 10, {__MODULE__, :monitor_callback})
               |> Reader.handle_collect(init_stats(state.stats, procs: procs2))

               Process.sleep(10)
             end) == expected
    end

    test "monitor process env monitor", %{state: state, procs1: procs1, procs2: procs2} do
      if Process.whereis(Etop), do: Etop.stop()

      Application.put_env(
        :etop,
        :monitor,
        {:process, :message_queue_len, 10, {Reader, :monitor_msgq_callback}}
      )

      Application.put_env(:etop, :monitor_kill, false)

      {:ok, state} = Etop.init(os_pid: state.os_pid, cores: state.cores, util: state.stats.util)

      [log] =
        capture_log(fn ->
          state
          |> init_stats(procs: procs1)
          |> Reader.handle_collect(init_stats(state.stats, procs: procs2))

          Process.sleep(5)
        end)
        |> String.split("\n", trim: true)
        |> Enum.reject(&(&1 =~ ~r/^\e/))

      assert log =~ "Killing process with msgq: '12', info: %{"
      assert log =~ "pid: #PID<0.6.0>"

      Application.put_env(:etop, :monitor, nil)
    end

    @util1 {
      "cpu  11591135 66 3749423 1682036710 197096 216 150115 112640 0\n",
      "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 32314 5816 0 0 261 26 0 0 20 0 28 0 283041891 3066802176 23134 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
    }
    @util2 {
      "cpu  11591149 66 3749428 1682037290 197096 216 150115 112640 0\n",
      "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 32506 5816 0 0 274 27 0 0 20 0 28 0 283041891 3065569280 22862 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
    }
    @tag init_stats: [load: %{sys: 1.0, total: 100.5, user: 99.5}, util: @util1]
    test "monitor cpu total", %{state: state, procs2: procs2} do
      self = self()

      callback = fn item, value -> send(self, {:exceeded, item, value}) end

      state
      |> Etop.monitor(:summary, [:load, :total], 14.0, callback)
      |> Reader.handle_collect(init_stats(state.stats, procs: procs2, util: @util2))

      assert_receive {:exceeded, load, 14.0}
      assert load == %{sys: 1.0, total: 14.0, user: 13.0}

      refute_receive {:exceeded, _, _}
    end

    test "monitor memory total", %{state: state, procs2: procs2} do
      self = self()

      callback = fn item, value -> send(self, {:exceeded, item, value}) end

      state
      |> Etop.monitor(:summary, [:memory, :total], 30_000_000, callback)
      |> Reader.handle_collect(init_stats(state.stats, procs: procs2, util: @util2))

      total = @default_memory.total
      assert_receive {:exceeded, load, ^total}

      assert load == @default_memory

      refute_receive({:exceeded, _, _})
    end

    @tag init_stats: [load: %{sys: 1.0, total: 100.5, user: 99.5}, util: @util1]
    test "monitor cpu.total and msgq", %{state: state, procs2: procs2} do
      self = self()

      callback1 = fn item, value -> send(self, {:exceeded1, item, value}) end
      callback2 = fn item, value -> send(self, {:exceeded2, item, value}) end

      state
      |> Etop.monitor(:summary, [:memory, :total], 30_000_000, callback1)
      |> Etop.add_monitor(:summary, [:load, :total], 14.0, callback2)
      |> Reader.handle_collect(init_stats(state.stats, procs: procs2, util: @util2))

      total = @default_memory.total
      assert_receive {:exceeded1, @default_memory, ^total}
      refute_receive {:exceeded1, _, _}

      assert_receive {:exceeded2, %{sys: 1.0, total: 14.0, user: 13.0}, 14.0}
      refute_receive {:exceeded2, _, _}
    end
  end

  def monitor_callback(info, _value) do
    IO.inspect(info, pretty: true, limit: :infinity)
  end

  defp init_stats(state, opts)

  defp init_stats(%{stats: stats} = state, opts) do
    %{state | stats: init_stats(stats, opts)}
  end

  defp init_stats(stats, opts) do
    %{
      util: opts[:util] || stats.util,
      memory: opts[:memory] || @default_memory,
      load: opts[:load] || %{sys: 0.0, total: 0.0, user: 0.0},
      node: "nonode@nohost",
      nprocs: "101",
      runq: 0,
      procs: opts[:procs] || []
    }
  end

  defp get_stats(state) do
    Reader.remote_stats(state)
    assert_receive {:result, stats}
    Etop.sanitize_stats(state, stats)
  end
end
