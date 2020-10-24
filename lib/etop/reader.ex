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

  alias Etop.Utils

  require Logger

  @doc """
  Get the number of CPU Cores.
  """
  def core_count do
    with topology <- :erlang.system_info(:cpu_topology),
         processors when is_list(processors) <- topology[:processor] do
      {:ok, length(processors)}
    else
      _ -> :error
    end
  end

  @doc """
  Handle the timer timeout.

  Collect and report the Top information.
  """
  def handle_collect(state, stats) do
    Logger.debug(fn -> "handle_collect start" end)

    stats =
      stats
      |> calculate_load(state)
      |> parse_system_info()
      |> calculate_reductions(state)
      |> get_processes(state)

    %{state | stats: stats}
  end

  @doc """
  Fetch the initial CPU information.

  Gets the os_pid and core count.
  """
  def remote_cpu_info(%{node: node}) when is_nil(node) do
    os_pid = os_pid()

    send(
      self(),
      {:cpu_info_result,
       %{
         cores: core_count(),
         os_pid: os_pid,
         util: read_stats(os_pid)
       }}
    )
  end

  def remote_cpu_info(%{node: node}) when is_atom(node) do
    pid = self()

    core_count = fn ->
      with topology <- :erlang.system_info(:cpu_topology),
           processors when is_list(processors) <- topology[:processor] do
        {:ok, length(processors)}
      else
        _ -> :error
      end
    end

    os_pid = fn -> List.to_integer(:os.getpid()) end

    Node.spawn_link(node, fn ->
      os_pid = os_pid.()

      send(
        pid,
        {:cpu_info_result,
         %{
           cores: core_count.(),
           os_pid: os_pid,
           util: {File.read("/proc/stat"), File.read("/proc/#{os_pid}/stat")}
         }}
      )
    end)
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
  def remote_stats(%{node: node}) when not is_nil(node) do
    # TODO: This isn't working. It works if I call this directly from iex>,
    # but raises an error its called from the GenServer.
    # Also note that the code below is duplicate code. Once It works, it should
    # be refactored to use the same as the local version.

    pid = self()

    Node.spawn_link(node, fn ->
      send(
        pid,
        {:result,
         %{
           procs:
             Process.list()
             |> Enum.map(fn ppid ->
               if info = Process.info(ppid),
                 do: {ppid, Keyword.put(info, :memory, :erlang.process_info(ppid, :memory))},
                 else: nil
             end),
           nprocs: :process_count |> :erlang.system_info() |> to_string(),
           memory: Enum.into(:erlang.memory(), %{}),
           runq: :erlang.statistics(:run_queue),
           util: {File.read("/proc/stat"), File.read("/proc/#{pid}/stat")}
         }}
      )
    end)
  end

  def remote_stats(state) do
    # Get the stats from the local node
    send(self(), {:result, get_stats(state.os_pid)})
  end

  ###############
  # Private

  defp calculate_load(%{util: curr} = stats, %{stats: %{util: prev}, cores: cores}) do
    {load, util} = calculate_load(curr, prev, cores)

    stats |> Map.put(:load, load) |> Map.put(:util, util)
  end

  defp calculate_load({_, _} = curr, {_, _} = prev, cores) do
    curr = parse_util(curr)
    {CpuUtil.process_util(parse_util(prev), curr, cores: cores), curr}
  end

  defp calculate_load({_, _} = curr, _, _) do
    {nil, parse_util(curr)}
  end

  defp calculate_load(_, _, _) do
    {nil, nil}
  end

  defp calculate_reductions(%{procs: curr} = stats, %{stats: %{procs: prev}}) do
    prev = if prev, do: prev, else: %{}

    {process_list, total} =
      Enum.reduce(curr, {[], 0}, fn {pid, settings}, {acc, total} ->
        with %{reductions: reds2} <- prev[pid] || @prev_default,
             %{reductions: reds1} <- settings do
          reds = reds1 - reds2
          {[{pid, Map.put(settings, :reductions_diff, reds)} | acc], total + reds}
        else
          _ -> {acc, total}
        end
      end)

    {Map.put(stats, :total, total), process_list}
  end

  defp get_processes({stats, process_list}, state) do
    processes =
      process_list
      |> Utils.sort(state.sort, secondary: :reductions_diff)
      |> Enum.take(state.nprocs)

    Map.put(stats, :processes, processes)
  end

  def get_stats(pid),
    do: %{
      procs:
        Process.list()
        |> Enum.map(fn ppid ->
          if info = Process.info(ppid),
            do: {ppid, Keyword.put(info, :memory, :erlang.process_info(ppid, :memory))},
            else: nil
        end),
      nprocs: :process_count |> :erlang.system_info() |> to_string(),
      memory: Enum.into(:erlang.memory(), %{}),
      runq: :erlang.statistics(:run_queue),
      util: read_stats(pid)
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

  defp os_pid do
    List.to_integer(:os.getpid())
  end

  defp parse_system_info(%{procs: procs} = stats) do
    %{stats | procs: parse_system_info(procs)}
  end

  defp parse_system_info(procs) do
    procs
    |> Enum.map(fn {pid, item} ->
      {pid,
       item
       |> info_map_memory()
       |> Map.take(@info_fields)}
    end)
    |> Enum.into(%{})
  end

  defp parse_util({{:ok, stat}, {:ok, statp}}), do: {stat, statp}
  defp parse_util({stat, statp} = util) when is_binary(stat) and is_binary(statp), do: util
  defp parse_util(_), do: nil

  defp read_stats(os_pid), do: {File.read("/proc/stat"), File.read("/proc/#{os_pid}/stat")}
end
