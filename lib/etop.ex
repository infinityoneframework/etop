defmodule Etop do
  @sort_fields ~w(memory msgq reds reds_diff status default)a

  @moduledoc """
  A Top like implementation for Elixir Applications.

  ## Usage

      # Start with default options
      ex> Etop.start()

      # Temporarily pause/stop
      ex> Etop.pause()

      # Restart when paused
      ex> Etop.start

      # Start logging to an exs file
      ex> Etop.start file: "/tmp/etop.exs"

      # Load the current exs file
      ex> data = Etop.load

      # Start then change number of processes and interval between collecting results
      ex> Etop.start
      ex> Etop.set_opts nprocs: 15, interval: 15_000

      # or
      ex> Etop.start
      ex> Etop.pause
      ex> Etop.start nprocs: 15, interval: 15_000

      # Stop Etop, killing its GenServer
      ex> Etop.stop

  ## Configuration

  * `file` - Save the output to a file.
  * `format` - the output file format. Values [:text, :exs]
  * `interval (5000)` - the time (ms) between each run
  * `nprocs (10)` - the number of processes to list
  * `sort (reds_diff)` - the field to sort the process list. Values #{inspect(@sort_fields)}
  """
  use GenServer

  alias Etop.{Reader, Report}

  require Logger

  @name __MODULE__
  @valid_opts ~w(freq length debug file os_pid cores format interval nprocs sort monitors reporting human)a

  @sortable ~w(memory message_queue_len reductions reductions_diff status)a
  @sort_field_mapper @sort_fields
                     |> Enum.zip(@sortable)
                     |> Keyword.put(:default, :reductions_diff)

  @type monitor_callback :: (any(), any() -> none()) | {atom(), atom()}
  @type monitor_type :: :process | :summary
  @type monitor_fields :: atom() | [atom()]
  @type monitor :: {monitor_type(), monitor_fields(), any(), monitor_callback()}
  @type monitors :: [monitor()]

  @callback alive? :: boolean()
  @callback add_monitor(monitor_type(), monitor_fields(), any(), monitor_callback()) ::
              no_return()
  @callback monitor(monitor_type(), monitor_fields(), any(), monitor_callback()) :: no_return()
  @callback start(keyword()) :: GenServer.on_start()
  @callback stop() :: any()
  @callback monitors() :: [tuple()]
  @callback remove_monitors() :: any()

  ###############
  # Public API

  @doc """
  Add a new monitor.

  Adds the given monitor to any existing monitors.

  ## Examples

      iex> Etop.start()
      iex> callback = &{&1, &2, &3}
      iex> Etop.monitor(:summary, [:load, :sys], 10.0, callback)
      iex> Etop.add_monitor(:process, :reductions, 1000, callback)
      iex> Etop.monitors() ==
      ...> [
      ...>   {:process, :reductions, 1000, callback},
      ...>   {:summary, [:load, :sys], 10.0, callback}
      ...> ]
      true
  """
  @spec add_monitor(monitor_type(), monitor_fields(), any(), monitor_callback()) :: no_return()
  def add_monitor(type, field, threshold, callback) do
    GenServer.cast(@name, {:add_monitor, {type, field, threshold, callback}})
  end

  @doc """
  Add a new monitor to an Etop state map.
  """
  @spec add_monitor(
          %{:monitors => monitors()},
          monitor_type(),
          monitor_fields(),
          any(),
          monitor_callback()
        ) :: %{:monitors => monitors()}
  def add_monitor(state, type, field, threshold, callback) do
    %{state | monitors: [{type, field, threshold, callback} | state.monitors]}
  end

  @doc """
  Test if Etop is running.

      iex> Etop.alive?()
      false

      iex> Etop.start()
      iex> Etop.alive?()
      true
  """
  @spec alive?() :: boolean()
  def alive?, do: if(pid = Process.whereis(@name), do: Process.alive?(pid), else: false)

  @doc """
  Restart Etop if its halted.
  """
  def continue(opts \\ []) do
    if Process.whereis(@name) do
      GenServer.call(@name, {:continue, opts})
    else
      {:error, :no_process}
    end
  end

  @doc """
  Set a monitor.

  Replaces any existing monitors with the given monitor.

  ## Examples

      iex> Etop.start()
      iex> callback = &{&1, &2, &3}
      iex> Etop.monitor(:summary, [:load, :sys], 10.0, callback)
      iex> Etop.monitors() == [{:summary, [:load, :sys], 10.0, callback}]
      true
  """
  @spec monitor(monitor_type(), monitor_fields(), any(), monitor_callback()) :: no_return()
  def monitor(type, field, threshold, callback) do
    GenServer.cast(@name, {:monitor, {type, field, threshold, callback}})
  end

  @spec monitor(
          %{:monitors => monitors()},
          monitor_type(),
          monitor_fields(),
          any(),
          monitor_callback()
        ) :: %{:monitors => monitors()}
  def monitor(state, type, field, threshold, callback) do
    set_opts(state, monitors: [{type, field, threshold, callback}])
  end

  @doc """
  Get the current monitors.

  ## Examples

      iex> Etop.start()
      iex> callback = &{&1, &2, &3}
      iex> Etop.monitor(:summary, [:load, :sys], 10.0, callback)
      iex> Etop.monitors() == [{:summary, [:load, :sys], 10.0, callback}]
      true
  """
  @spec monitors() :: [tuple()]
  def monitors do
    GenServer.call(@name, :monitors)
  end

  @doc """
  Load the current exs log file.
  """
  def load do
    GenServer.call(@name, :load)
  end

  @doc """
  Load the given exs log file.
  """
  def load(path) do
    Report.load(path)
  end

  @doc """
  Pause a running Etop session.
  """
  def pause do
    GenServer.call(@name, :pause)
  end

  @doc """
  Remove all monitors.

  ## Examples

      iex> Etop.start()
      iex> Etop.monitor(:summary, [:load, :total], 10.0, &IO.inspect({&1, &2, &3}))
      iex> Etop.remove_monitors()
      iex> Etop.monitors()
      []
  """
  def remove_monitors do
    GenServer.cast(@name, :remove_monitors)
  end

  @doc """
  Remove a monitor.

  ## Examples

      iex> Etop.start()
      iex> Etop.monitor(:summary, [:load, :total], 10.0, &IO.inspect({&1, &2, &3}))
      iex> response = Etop.remove_monitor(:summary, [:load, :total], 10.0)
      iex> {response, Etop.monitors()}
      {:ok, []}
  """
  @spec remove_monitor(monitor_type(), monitor_fields(), any()) :: :ok | :not_found
  def remove_monitor(type, field, threshold) do
    GenServer.call(@name, {:remove_monitor, {type, field, threshold}})
  end

  @doc """
  Enable or disable reporting.

  Disabling reporting stops reporting printing or logging reports but keeps the Etop collecting
  data. This option can be used with a monitor to toggle logging when a threshold is reached.

  ## Examples

      iex> Etop.start()
      iex> Etop.reporting(false)
      :ok

      iex> Etop.start()
      iex> enable_callback = fn _, _, state -> %{state | reporting: true} end
      iex> disable_callback = fn _, value, state ->
      ...>   if value < 40.0, do: %{state | reporting: false}
      ...> end
      iex> Etop.monitor(:summary, [:load, :total], 50.0, enable_callback)
      iex> Etop.add_monitor(:summary, [:load, :total], 40.0, disable_callback)
      :ok
  """
  @spec reporting(boolean()) :: :ok | :already_reporting | :no_reporting
  def reporting(enable?) do
    GenServer.call(@name, {:reporting, enable?})
  end

  @doc """
  Set Etop settings
  """
  def set_opts(opts) do
    if valid_opts?(opts) do
      GenServer.cast(@name, {:set_opts, opts})
    else
      {:error, :invalid_opts}
    end
  end

  @doc """
  Start Etop Reporting.
  """
  @spec start(keyword()) :: GenServer.on_start()
  def start(opts \\ []) do
    GenServer.start(__MODULE__, opts, name: @name)
  end

  @doc """
  Stop Etop Reporting.
  """
  def stop() do
    GenServer.cast(@name, :stop)
  end

  @doc """
  Get the status of the server
  """
  def status do
    GenServer.call(@name, :status)
  end

  def status! do
    GenServer.call(@name, :status!)
  end

  ######################
  # GenServer Callbacks

  def init(opts) do
    send(self(), {:initialize, opts[:first_interval] || 1000})

    if node = opts[:node] do
      Node.connect(node)
    end

    monitors =
      if monitors = opts[:monitors] || Application.get_env(:etop, :monitor),
        do: List.flatten([monitors]),
        else: []

    {:ok,
     set_file(
       %{
         cores: opts[:cores] || 1,
         debug: opts[:debug] || false,
         file: nil,
         format: nil,
         halted: Keyword.get(opts, :halted, false),
         info_map: nil,
         interval: opts[:interval] || opts[:freq] || 5000,
         monitors: validate_monitors!(monitors),
         node: opts[:node],
         nprocs: opts[:nprocs] || opts[:length] || 10,
         os_pid: opts[:os_pid],
         stats: %{util: opts[:util], procs: nil, total: 0, load: nil},
         timer_ref: nil,
         sort: @sort_field_mapper[Keyword.get(opts, :sort, :default)],
         reporting: Keyword.get(opts, :reporting, true),
         human: Keyword.get(opts, :human, true)
       },
       opts
     )}
  end

  def handle_call({:remove_monitor, {which, fields, threshold}}, _, state) do
    monitors =
      Enum.reject(state.monitors, fn
        {^which, ^fields, ^threshold, _} -> true
        _ -> false
      end)

    if state.monitors == monitors do
      reply(state, :not_found)
    else
      reply(%{state | monitors: monitors}, :ok)
    end
  end

  def handle_call(:status, _, state) do
    reply(state, %{state | stats: Map.delete(state.stats, :procs)})
  end

  def handle_call(:status!, _, state) do
    reply(state, state)
  end

  def handle_call({:continue, opts}, _, %{halted: true} = state) do
    %{set_opts(state, opts) | halted: false}
    |> start_timer(state.interval)
    |> reply(:ok)
  end

  def handle_call({:continue, _}, _, state) do
    reply(state, :not_halted)
  end

  def handle_call(:load, _, %{format: :exs, file: file} = state) when is_binary(file) do
    reply(state, Report.load(file))
  end

  def handle_call(:load, _, state) do
    reply(state, {:error, :invalid_file})
  end

  def handle_call(:monitors, _, state) do
    reply(state, state.monitors)
  end

  def handle_call(:pause, _, %{halted: true} = state) do
    reply(state, :already_halted)
  end

  def handle_call(:pause, _, state) do
    reply(cancel_timer(%{state | halted: true}), :ok)
  end

  def handle_call({:reporting, value}, _, %{reporting: existing} = state)
      when value != existing do
    reply(%{state | reporting: value}, :ok)
  end

  def handle_call({:reporting, true}, _, state) do
    reply(state, :already_reporting)
  end

  def handle_call({:reporting, false}, _, state) do
    reply(state, :not_reporting)
  end

  def handle_cast({:add_monitor, monitor}, state) do
    monitors = state.monitors || []
    noreply(%{state | monitors: [monitor | monitors]})
  end

  def handle_cast({:monitor, monitor}, state) do
    state = if valid_monitor?(monitor), do: %{state | monitors: [monitor]}, else: state
    noreply(state)
  end

  def handle_cast(:remove_monitors, state) do
    noreply(%{state | monitors: []})
  end

  def handle_cast({:set_opts, opts}, state) do
    state
    |> set_opts(opts)
    |> noreply()
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info({:cpu_info_result, info}, %{stats: stats} = state) do
    info = sanitize_info_result(info)
    stats = Map.put(stats, :util, info.util)

    noreply(%{state | cores: info.cores, os_pid: info.os_pid, stats: stats})
  end

  def handle_info({:initialize, delay}, state) do
    # Run the report in 1 second.
    Process.send_after(self(), :collect, delay)

    Reader.remote_cpu_info(state)

    noreply(state)
  end

  def handle_info({:result, stats}, state) do
    Logger.debug(fn -> "handle_info :result" end)
    # Process the the main data and wait for info event {:info_response, info_map}

    stats = sanitize_stats(state, stats)

    state
    |> Reader.handle_collect(stats)
    |> Report.handle_report()
    |> noreply()
  end

  def handle_info(:collect, %{halted: true} = state) do
    noreply(state)
  end

  def handle_info(:collect, state) do
    Logger.debug(fn -> "handle_info :collect" end)
    # Start collecting the data. The summary and process data will be received by
    # info message {:result, stats}
    Reader.remote_stats(state)

    noreply(state |> start_timer())
  end

  def handle_info(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info(event, state) do
    Logger.debug(fn -> "unexpected info event #{inspect(event)}" end)
    noreply(state)
  end

  def terminate(reason, state) do
    cancel_timer(state)
    Logger.debug(fn -> "terminate #{inspect(reason)}" end)
    :ok
  end

  ############
  # Helpers

  def statistics(item), do: :erlang.statistics(item)

  def sanitize_stats(state, stats) do
    stats
    |> Map.put(:node, state.node || "nonode@nohost")
    |> Map.put(:procs, Enum.reject(stats.procs, &is_nil/1))
  end

  def sanitize_info_result(info) do
    info
    |> sanitize_info_result(:util)
    |> sanitize_info_result(:cores, 1)
  end

  #########
  # Private

  defp cancel_timer(%{timer_ref: nil} = state), do: state

  defp cancel_timer(%{timer_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | timer_ref: nil}
  end

  defp get_file_format(opts) do
    path = opts[:file]

    cond do
      val = opts[:format] -> val
      path && Path.extname(path) == ".exs" -> :exs
      true -> :text
    end
  end

  defp maybe_set_file(state, opts) do
    if Keyword.has_key?(opts, :file) do
      set_file(state, opts)
    else
      state
    end
  end

  defp set_file(state, opts) do
    %{state | file: opts[:file], format: get_file_format(opts)}
  end

  defp set_opts(state, opts) do
    if valid_opts?(opts) do
      opts
      |> Enum.reduce(state, fn {k, v}, state -> Map.put(state, k, v) end)
      |> set_opts_sort(opts[:sort])
      |> maybe_set_file(opts)
    else
      Logger.info("Invalid opts")
      state
    end
  end

  defp set_opts_sort(state, nil), do: Map.put(state, :sort, @sort_field_mapper[:default])
  defp set_opts_sort(state, field), do: Map.put(state, :sort, @sort_field_mapper[field])

  defp start_timer(%{interval: interval} = state) do
    start_timer(state, interval)
  end

  defp start_timer(state, interval) when is_integer(interval) do
    %{state | timer_ref: Process.send_after(self(), :collect, interval)}
  end

  def reply(%{} = state, reply), do: {:reply, reply, state}
  def reply(state, _), do: raise("invalid state: #{inspect(state)}")

  def noreply(%{} = state), do: {:noreply, state}
  def noreply(state), do: raise("invalid state: #{inspect(state)}")

  defp sanitize_info_result(info, field, default \\ nil)

  defp sanitize_info_result(%{util: {{:ok, stat}, {:ok, statp}}} = info, :util, _) do
    %{info | util: {stat, statp}}
  end

  defp sanitize_info_result(%{cores: {:ok, cores}} = info, :cores, _) do
    %{info | cores: cores}
  end

  defp sanitize_info_result(info, field, default) do
    Map.put(info, field, default)
  end

  defp valid_monitor?({which, field, threshold, callback}) do
    which in ~w(process summary)a and (is_atom(field) or is_list(field)) and is_number(threshold) and
      (is_nil(callback) or is_function(callback, 3) or is_tuple(callback))
  end

  defp valid_monitor?(nil), do: true

  defp valid_monitor?(_), do: false

  defp valid_monitors?([]), do: true

  defp valid_monitors?(list) when is_list(list), do: Enum.all?(list, &valid_monitor?/1)

  defp valid_monitors?(monitor), do: valid_monitor?(monitor)

  defp validate_monitors!(monitors) do
    unless valid_monitors?(monitors) do
      raise "Invalid monitor #{inspect(monitors)}"
    end

    monitors
  end

  defp in?(list), do: &(&1 in list)

  defp valid_opts?(opts) do
    keys? =
      opts
      |> Keyword.keys()
      |> Enum.all?(in?(@valid_opts))

    keys? and valid_sort_option?(opts[:sort]) and valid_monitors?(opts[:monitors])
  end

  defp valid_sort_option?(nil), do: true
  defp valid_sort_option?(sort), do: sort in @sort_fields
end
