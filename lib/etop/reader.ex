defmodule Etop.Reader do
  @moduledoc """
  Helpers for Etop.
  """
  @prev_default %{reductions: 0}
  @info_fields [
    :memory,
    :message_queue_len,
    :registered_name,
    :current_function,
    :initial_call,
    :reductions,
    :dictionary,
    :status
  ]

  require Logger

  @doc """
  Handle the timer timeout.

  Collect and report the Top information.
  """
  def handle_collect(state, stats) do
    Logger.debug(fn -> "handle_collect start" end)

    util2 =
      case stats[:util2] do
        {:ok, contents} ->
          CpuUtil.pid_util(contents)

        _ ->
          nil
      end

    load =
      if util2 do
        CpuUtil.calc_pid_util(state.util, util2, state.cores)
      else
        nil
      end

    stats = %{stats | procs: parse_system_info(stats.procs), load: load, util2: util2}

    {current, total} = calc_reductions(stats.procs, state.prev)

    list =
      current
      |> sort()
      |> Enum.take(state.nprocs)

    Logger.debug(fn -> "handle_collect done" end)
    %{state | prev: stats.procs, util: util2, total: total, stats: stats, list: list}
  end

  @doc """
  Fetch the top stats from either a current node or a remote node.

  Gets the following information and sends `{:result, info_map}` to the calling process:

      %{
        procs: List of Process.info(pid) with memory stats added,
        nprocs: total process count,
        memory: overall memory information,
        runq: length of the run queue,
        util2: contents of "/proc/<os-pid>/stat",
      }

  NOTE: remote nodes are not working.
  """
  def remote_stats(%{node: node, os_pid: os_pid}) when not is_nil(node) do
    # TODO: This isn't working. It works if I call this directly from iex>,
    # but raises an error its called from the GenServer.
    # Also note that the code below is duplicate code. Once It works, it should
    # be refactored to use the same as the local version.

    # IO.inspect(node, label: "remote_stats")
    pid = self()

    Node.spawn_link(node, fn ->
      send(
        pid,
        {:result,
         %{
           procs:
             Process.list()
             |> Enum.map(
               &{&1, Keyword.put(Process.info(&1), :memory, :erlang.process_info(&1, :memory))}
             ),
           nprocs: :process_count |> :erlang.system_info() |> to_string(),
           memory: Enum.into(:erlang.memory(), %{}),
           runq: :erlang.statistics(:run_queue),
           util2: File.read("/proc/#{os_pid}/stat"),
           load: nil
         }}
      )
    end)

    # IO.puts("ran remote_stats")
  end

  def remote_stats(state) do
    # Get the stats from the local node
    send(self(), {:result, get_stats(state.os_pid)})
  end

  @doc """
  Configurable sort.

  ## Arguments

  * `list` - the enumerable to be sorted.
  * `field` (:reductions_diff) - the field to be sorted on.
  * `field_fn` (fn field -> &elem(&1, 1)[field] end) - function to get the field.
  * `sorter_fn` (&>/2) -> Sort comparator (default descending)
  """
  def sort(
        list,
        field \\ :reductions_diff,
        field_fn \\ fn field -> &elem(&1, 1)[field] end,
        sorter_fn \\ &>/2
      ) do
    Enum.sort_by(list, field_fn.(field), sorter_fn)
  end

  ###############
  # Private

  defp calc_reductions(curr, prev) do
    prev = if prev, do: prev, else: %{}

    Enum.reduce(curr, {[], 0}, fn {pid, settings}, {acc, total} ->
      with %{reductions: reds2} <- prev[pid] || @prev_default,
           %{reductions: reds1} <- settings do
        reds = reds1 - reds2
        {[{pid, Map.put(settings, :reductions_diff, reds)} | acc], total + reds}
      else
        _ -> {acc, total}
      end
    end)
  end

  def get_stats(pid),
    do: %{
      procs:
        Process.list()
        |> Enum.map(
          &{&1, Keyword.put(Process.info(&1), :memory, :erlang.process_info(&1, :memory))}
        ),
      nprocs: :process_count |> :erlang.system_info() |> to_string(),
      memory: Enum.into(:erlang.memory(), %{}),
      runq: :erlang.statistics(:run_queue),
      util2: File.read("/proc/#{pid}/stat"),
      load: nil
    }

  defp info_map_memory(%{} = item) do
    case item.memory do
      {:memory, memory} -> %{item | memory: memory}
      memory when is_integer(memory) -> %{item | memory: memory}
      _ -> %{item | memory: 0}
    end
  end

  defp info_map_memory(item) when is_list(item) do
    item
    |> Enum.into(%{})
    |> info_map_memory()
  end

  defp parse_system_info(info) do
    info
    |> Enum.map(fn {pid, item} ->
      {pid,
       item
       |> info_map_memory()
       |> Map.take(@info_fields)}
    end)
    |> Enum.into(%{})
  end
end
