defmodule Etop.Monitor do
  require Logger

  def run(params, %{monitors: monitors, stats: %{procs: procs}} = state)
      when is_nil(monitors) or is_nil(procs) or monitors == [] do
    {params, state}
  end

  def run(params, %{monitors: monitors, stats: stats} = state) when is_list(monitors) do
    {params, Enum.reduce(monitors, state, &check_and_run(&1, params, stats, &2))}
  end

  def run_monitors(params, %{monitors: monitor, stats: stats} = state) when is_tuple(monitor) do
    {params, check_and_run(monitor, params, stats, state)}
  end

  def monitor_msgq_callback(info, value, state) do
    Logger.warn("Killing process with msgq: '#{inspect(value)}', info: #{inspect(info)}")
    if Application.get_env(:etop, :monitor_kill, true), do: Process.exit(info.pid, :kill)
    state
  end

  defp check_and_run({:process, field, threshold, callback}, {_, prev}, %{procs: curr}, state) do
    prev = Enum.into(prev, %{})

    Enum.reduce(curr, state, fn {pid, info}, state ->
      if exceeds_threshold?(info, field, threshold) and
           exceeds_threshold?(prev[pid], field, threshold) do
        info
        |> Map.put(:pid, pid)
        |> run_callback(info[field], callback, state)
      else
        state
      end
    end)
  end

  defp check_and_run({:summary, fields, threshold, callback}, {curr, _}, prev, state) do
    if exceeds_threshold?(curr, fields, threshold) and
         exceeds_threshold?(prev, fields, threshold) do
      curr
      |> get_in([hd(fields)])
      |> run_callback(get_in(curr, fields), callback, state)
    else
      state
    end
  end

  defp exceeds_threshold?(info, field, threshold)
       when is_atom(field) and (is_list(info) or is_map(info)) do
    !!info[field] && info[field] >= threshold
  end

  defp exceeds_threshold?(stats, fields, threshold)
       when is_list(fields) and (is_list(stats) or is_map(stats)) do
    value = get_in(stats, fields)
    !!value && value >= threshold
  end

  defp exceeds_threshold?(_, _, _), do: false

  defp run_callback(info, value, callback, state) when is_function(callback, 3) do
    try_callback(info, value, callback, state)
  end

  defp run_callback(info, value, {mod, fun}, state) do
    if function_exported?(mod, fun, 3) do
      try_callback(info, value, &apply(mod, fun, [&1, &2, &3]), state)
    else
      Logger.warn("&#{mod}.#{fun}/3 is not a valid callback")
      state
    end
  end

  # Safely run a monitor callback.
  # Run the callback and check the return for something that resembles a state map.
  # If so, return that map, otherwise return the original state map.
  defp try_callback(info, value, callback, state) do
    try do
      case callback.(info, value, state) do
        %{monitors: _, file: _, format: _} = state -> state
        _ -> state
      end
    rescue
      e ->
        Logger.warn("monitor callback exception: #{inspect e}, callback: #{inspect callback}")
        state
     end
  end
end
