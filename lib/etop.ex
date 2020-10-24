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
  @valid_opts ~w(freq length debug file os_pid cores format interval nprocs sort)a

  @sortable ~w(memory message_queue_len reductions reductions_diff status)a
  @sort_field_mapper @sort_fields
                     |> Enum.zip(@sortable)
                     |> Keyword.put(:default, :reductions_diff)

  ###############
  # Public API

  @doc """
  Load the current exs log file.
  """
  def load do
    GenServer.call(@name, :load)
  end

  @doc """
  Load the given .exs file.
  """
  def load(path) do
    Etop.Report.load(path)
  end

  @doc """
  Pause a running Etop session.
  """
  def pause do
    GenServer.call(@name, :pause)
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
  def start(opts \\ []) do
    if Process.whereis(@name) do
      GenServer.call(@name, {:start, opts})
    else
      GenServer.start(__MODULE__, opts, name: @name)
    end
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
         node: opts[:node],
         nprocs: opts[:nprocs] || opts[:length] || 10,
         os_pid: opts[:os_pid],
         stats: %{util: opts[:util], procs: nil, total: 0, load: nil},
         timer_ref: nil,
         sort: @sort_field_mapper[Keyword.get(opts, :sort, :default)]
       },
       opts
     )}
  end

  def handle_call(:status, _, state) do
    reply(state, %{state | stats: Map.delete(state.stats, :procs)})
  end

  def handle_call(:status!, _, state) do
    reply(state, state)
  end

  def handle_call({:start, opts}, _, %{halted: true} = state) do
    %{set_opts(state, opts) | halted: false}
    |> start_timer(state.interval)
    |> reply(:ok)
  end

  def handle_call({:start, _}, _, state) do
    reply(state, :not_halted)
  end

  def handle_call(:load, _, %{format: :exs, file: file} = state) when is_binary(file) do
    reply(state, Report.load(file))
  end

  def handle_call(:load, _, state) do
    reply(state, {:error, :invalid_file})
  end

  def handle_call(:pause, _, %{halted: true} = state) do
    reply(state, :already_halted)
  end

  def handle_call(:pause, _, state) do
    reply(cancel_timer(%{state | halted: true}), :ok)
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

  defp reply(%{} = state, reply), do: {:reply, reply, state}
  defp reply(state, _), do: raise("invalid state: #{inspect(state)}")

  defp noreply(%{} = state), do: {:noreply, state}
  defp noreply(state), do: raise("invalid state: #{inspect(state)}")

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

  defp valid_opts?(opts) do
    keys? =
      opts
      |> Keyword.keys()
      |> Enum.all?(&(&1 in @valid_opts))

    keys? and valid_sort_option?(opts[:sort])
  end

  defp valid_sort_option?(nil), do: true
  defp valid_sort_option?(sort), do: sort in @sort_fields
end
