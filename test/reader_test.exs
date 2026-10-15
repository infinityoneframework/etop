defmodule Etop.ReaderTest do
  use ExUnit.Case

  alias Etop.{Fixtures, Reader}

  test "core_count returns a positive count even without CPU topology information" do
    assert {:ok, cores} = Reader.core_count()
    assert is_integer(cores) and cores > 0
  end

  setup do
    cores = 6
    os_pid = CpuUtil.getpid()
    util = Fixtures.proc_stat1()
    {:ok, state} = Etop.init(os_pid: os_pid, cores: cores, util: util)

    {:ok, state: state, stat1: Fixtures.proc_stat1(), stat2: Fixtures.proc_stat2()}
  end

  test "remote_cpu_info/1 local", %{state: state} do
    Reader.remote_cpu_info(state)

    assert_receive {:cpu_info_result, info}

    %{
      cores: {:ok, cores},
      os_pid: os_pid,
      util: util
    } = info

    assert is_integer(cores)
    assert os_pid == state.os_pid
    assert_util(util)
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
      util: util
    } = stats

    assert nprocs =~ ~r/^\d+$/
    assert is_integer(runq) and runq >= 0
    assert_util(util)
    assert memory |> Map.keys() |> Enum.sort() == memory_keys
    assert Enum.all?(memory, &(&1 |> elem(1) |> is_integer()))
    assert length(procs) > 0

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

  defp assert_util(util) do
    if File.exists?("/proc/stat") do
      assert {{:ok, stat}, {:ok, process_stat}} = util
      assert stat =~ ~r/^cpu\s+\d+/
      assert process_stat =~ ~r/^\d+\s+\(.+\)/
    else
      assert util == {{:error, :enoent}, {:error, :enoent}}
    end
  end

  defp get_stats(state) do
    Reader.remote_stats(state)
    assert_receive {:result, stats}
    Etop.sanitize_stats(state, %{stats | util: Fixtures.proc_stat2()})
  end
end
