defmodule Etop.Monitor do
  @moduledoc """
  Etop Monitors.

  Add `:summary` or `:process` monitors to Etop. These monitors are checked on
  each run. If the threshould condition is met, the monitor's callback if called.

  Monitors are added with either the `Etop.monitor/4` or `Etop.add_monitor/4` calls.
  """
  require Logger

  @doc """
  Run the monitor checks.
  """
  @spec run(any(), map()) :: {any(), map()}
  def run(params, %{monitors: monitors, stats: %{procs: procs}} = state)
      when is_nil(monitors) or is_nil(procs) or monitors == [] do
    {params, state}
  end

  def run(params, %{monitors: monitors, stats: stats} = state) when is_list(monitors) do
    {params, Enum.reduce(monitors, state, &check_and_run(&1, params, stats, &2))}
  end

  @spec run_monitors(any(), map()) :: {any(), map()}
  def run_monitors(params, %{monitors: monitor, stats: stats} = state) when is_tuple(monitor) do
    {params, check_and_run(monitor, params, stats, state)}
  end

  defp check_and_run({:process, field, threshold, callback}, {_, prev}, %{procs: curr}, state) do
    prev = Enum.into(prev, %{})

    Enum.reduce(curr, state, fn {pid, info}, state ->
      info = put_in(info, [:pid], pid)
      prev_info = if item = prev[pid], do: put_in(item, [:pid], pid), else: nil

      if exceeds_threshold?(state, info, field, threshold) and
           exceeds_threshold?(state, prev_info, field, threshold) do
        run_callback(info, info[field], callback, state)
      else
        state
      end
    end)
  end

  defp check_and_run({:summary, fields, threshold, callback}, {curr, _}, prev, state) do
    if exceeds_threshold?(state, curr, fields, threshold) and
         exceeds_threshold?(state, prev, fields, threshold) do
      curr
      |> get_in([hd(fields)])
      |> run_callback(get_in(curr, fields), callback, state)
    else
      state
    end
  end

  defp exceeds_threshold?(state, info, field, {fun, threshold}) when is_function(fun, 2) do
    exceeds_threshold?(state, info, field, fn value -> fun.(value, threshold) end)
  end

  defp exceeds_threshold?(state, info, field, {fun, threshold}) when is_function(fun, 3) do
    exceeds_threshold?(state, info, field, fn value -> fun.(value, threshold, state) end)
  end

  defp exceeds_threshold?(state, info, field, fun) when is_function(fun, 2) do
    exceeds_threshold?(state, info, field, fn value -> fun.(value, state) end)
  end

  defp exceeds_threshold?(state, info, field, fun) when is_function(fun, 3) do
    exceeds_threshold?(state, info, field, fn value -> fun.(value, info, state) end)
  end

  defp exceeds_threshold?(state, info, field, threshold) when not is_function(threshold) do
    exceeds_threshold?(state, info, field, &(&1 >= threshold))
  end

  defp exceeds_threshold?(_state, info, field, comparator)
       when is_function(comparator, 1) and is_atom(field) and (is_list(info) or is_map(info)) do
    comparator.(!!info[field] && info[field])
  end

  defp exceeds_threshold?(_state, stats, fields, comparator)
       when is_function(comparator, 1) and is_list(fields) and (is_list(stats) or is_map(stats)) do
    value = get_in(stats, fields)
    comparator.(!!value && value)
  end

  defp exceeds_threshold?(_, _, _, _), do: false

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
        Logger.warn("monitor callback exception: #{inspect(e)}, callback: #{inspect(callback)}")
        state
    end
  end
end
