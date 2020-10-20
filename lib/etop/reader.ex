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

  require IEx
  require Logger

  @doc """
  Handle the timer timeout.

  Collect and report the Top information.
  """
  def handle_collect(state, stats) do
    Logger.debug(fn -> "handle_collect start" end)

    # IO.inspect(stats, label: "handle_collect")
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

    # Logger.debug(fn -> "stats.procs length: #{length(stats.procs)}" end)

    {current, total} = calc_reductions(stats.procs, state.prev)

    list =
      current
      |> sort()
      |> Enum.take(state.nprocs)

    Logger.debug(fn -> "handle_collect done" end)
    # IEx.pry()
    %{state | prev: stats.procs, util: util2, total: total, stats: stats, list: list}
  end

  # def parse_system_info(info) when is_binary(info) do
  #   Logger.debug(fn ->
  #     len = Float.round(String.length(info) / 1000 / 1000, 2)
  #     "info length #{len}"
  #   end)

  #   info
  #   |> String.split("\n", trim: true)
  #   |> Enum.reduce({nil, nil, %{}}, fn
  #     "=" <> name, {nil, nil, acc} ->
  #       {name, %{}, acc}

  #     "=" <> name, {topic, map, acc} ->
  #       acc = Map.put(acc, topic, map)
  #       {name, %{}, acc}

  #     item, {topic, map, acc} ->
  #       map =
  #         case String.split(item, ":", parts: 2) do
  #           [name, value] ->
  #             Map.put(map, name, value)

  #           [one] ->
  #             Map.put(map, one, nil)
  #         end

  #       {topic, map, acc}
  #   end)
  #   |> add_last()
  # end

  def parse_system_info(info) do
    info
    |> Enum.map(fn {pid, item} ->
      {pid,
       item
       |> info_map_memory()
       |> Map.take(@info_fields)}
    end)
    |> Enum.into(%{})
  end

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

  # def remote_info(%{node: node}, pid_list) when not is_nil(node) do
  #   # IO.inspect(node, label: "remote_info")
  #   pid = self()

  #   Node.spawn_link(node, fn ->
  #     response =
  #       pid_list
  #       |> Enum.map(&{&1, Process.info(&1)})
  #       |> Enum.into(%{})

  #     send(pid, {:info_response, response})
  #   end)
  # end

  # def remote_info(_, pid_list) do
  #   response =
  #     pid_list
  #     |> Enum.map(&{&1, Process.info(&1)})
  #     |> Enum.into(%{})

  #   send(self(), {:info_response, response})
  # end

  def remote_stats(%{node: node}) when not is_nil(node) do
    # IO.inspect(node, label: "remote_stats")
    pid = self()

    # fun = fn ->
    #   result = %{
    #     # procs: :erlang.system_info(:procs),
    #     test: :hello,
    #     # nprocs: :process_count |> :erlang.system_info() |> to_string(),
    #     # memory: Enum.into(:erlang.memory(), %{}),
    #     # runq: :erlang.statistics(:run_queue),
    #     # util2: nil,
    #     # load: nil
    #   }
    #   # }
    #   # |> IO.inspect(label: "payload")
    #   # send(pid, {:result, result})
    # end

    # IO.inspect fun, label: "the fun"
    Node.spawn_link(node, fn ->
      send(pid, {:result, :test})
    end)

    IO.puts("ran remote_stats")
  end

  def remote_stats(state) do
    # IO.inspect(nil, label: "remote_stats")
    # util2 = if state.cpu_util?, do: CpuUtil.pid_util(state.os_pid), else: nil
    send(self(), {:result, get_stats(state.os_pid)})
  end

  def system_info, do: system_info(:info)

  def system_info(which) do
    which
    |> :erlang.system_info()
    |> parse_system_info()
  end

  ###############
  # Private

  defp add_last({topic, map, acc}), do: Map.put(acc, topic, map)

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

  # defp collect_info(list, state) do
  #   # IO.puts("collect_info")

  #   {pid_list, list} =
  #     list
  #     |> Enum.map(fn {pid_str, reds} ->
  #       pid_str = String.replace(pid_str, "proc:", "")
  #       pid = pid_str |> String.to_charlist() |> :erlang.list_to_pid()
  #       {pid, {pid_str, reds}}
  #     end)
  #     |> Enum.unzip()

  #   remote_info(state, pid_list)
  #   list
  # end

  def get_stats(pid),
    do: %{
      # procs: :erlang.system_info(:procs),
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

  # defp reductions_to_int(raw) do
  #   Enum.reduce(raw, %{}, fn {pid, settings}, acc ->
  #     settings =
  #       settings
  #       |> Keyword.take(
  #         ~w(memory message_queue_len registered_name current_function initial_call reductions)a
  #       )
  #       # ["Reductions", "Spawned as", "Memory", "State", "Message queue length"])
  #       |> Enum.into(%{})

  #     Map.put(acc, pid, settings)
  #     # with reds when is_binary(reds) <- settings["Reductions"],
  #     #      {num, _} <- reds |> String.trim() |> Integer.parse() do
  #     #   Map.put(acc, pid, Map.put(settings, "Reductions", num))
  #     # else
  #     #   _ -> acc
  #     # end
  #   end)
  # end

  defp sort(
         curr,
         field \\ :reductions_diff,
         field_fn \\ fn field -> &elem(&1, 1)[field] end,
         sorter_fn \\ &>/2
       ) do
    Enum.sort_by(curr, field_fn.(field), sorter_fn)
  end
end
