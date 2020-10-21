defmodule Etop do
  @moduledoc """
  A Top like implementation for Elixir Applications.

  ## Usage

      # Start with default options
      iex> Etop.start()

      # Temporarily pause/stop
      iex> Etop.pause()

      # Restart when paused
      iex> Etop.start

      # Start logging to an exs file
      iex> Etop.start file: "/tmp/etop.exs"

      # Load the current exs file
      iex> data = Etop.load

      # Start then change number of processes and interval between collecting results
      iex> Etop.start
      iex> Etop.set_opts nprocs: 15, interval: 15_000

      # or
      iex> Etop.start
      iex> Etop.pause
      iex> Etop.start nprocs: 15, interval: 15_000

      # Stop Etop, killing its GenServer
      iex> Etop.stop
  """
  use GenServer

  alias Etop.{Reader, Report}

  require Logger

  @name __MODULE__
  @valid_opts ~w(freq length debug file os_pid cores format interval npocs)a

  ###############
  # Public API

  @doc """
  Load the current exs log file.
  """
  def load do
    GenServer.call(@name, :load)
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
    # Run the report in 1 second.
    Process.send_after(self(), :collect, 1000)

    cpu_util? = Keyword.get(opts, :cpu_util, true)

    if cpu_sup?(), do: :cpu_sup.start()

    os_pid = CpuUtil.getpid()

    cores =
      if cpu_util? do
        with {:ok, cores} <- CpuUtil.num_cores(), do: cores
      else
        1
      end

    util = if cpu_util?, do: CpuUtil.pid_util(os_pid), else: nil

    if node = opts[:node] do
      Node.connect(node)
    end

    {:ok,
     set_file(
       %{
         cpu_util?: cpu_util?,
         cores: cores,
         debug: opts[:debug] || false,
         file: nil,
         format: nil,
         halted: Keyword.get(opts, :halted, false),
         info_map: nil,
         interval: opts[:interval] || opts[:freq] || 5000,
         list: nil,
         load: nil,
         node: opts[:node],
         nprocs: opts[:nprocs] || opts[:length] || 10,
         os_pid: os_pid,
         prev: nil,
         stats: nil,
         timer_ref: nil,
         total: 0,
         util: util
       },
       opts
     )}
  end

  def handle_call(:status, _, state) do
    reply(state, Map.delete(state, :prev))
  end

  def handle_call(:status!, _, state) do
    reply(state, state)
  end

  def handle_call({:start, opts}, _, %{halted: true} = state) do
    %{set_opts(state, opts) | halted: false}
    |> start_timer(1000)
    |> reply(:ok)
  end

  def handle_call({:start, _}, _, state) do
    reply(state, :not_halted)
  end

  def handle_call(:load, _, state) do
    if state.format == :exs and is_binary(state.file) do
      reply(state, Report.load(state.file))
    else
      reply(state, {:error, :invalid_file})
    end
  end

  def handle_call(:pause, _, %{halted: true} = state) do
    reply(state, :not_halted)
  end

  def handle_call(:pause, _, state) do
    reply(cancel_timer(%{state | halted: true}), :ok)
  end

  def handle_cast({:set_opts, opts}, state) do
    state = Enum.reduce(opts, state, fn {k, v}, state -> Map.put(state, k, v) end)

    state
    |> set_opts(opts)
    |> noreply()
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info({:result, stats}, state) do
    Logger.debug(fn -> "handle_info :result" end)
    # Process the the main data and wait for info event {:info_response, info_map}
    stats = Map.put(stats, :node, state.node || "nonode@nohost")

    state
    |> Reader.handle_collect(stats)
    |> Report.handle_report()

    noreply(state)
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
    if cpu_sup?(), do: :cpu_sup.stop()
    :ok
  end

  ############
  # Helpers

  def statistics(item), do: :erlang.statistics(item)

  #########
  # Private

  defp cancel_timer(%{timer_ref: nil} = state), do: state

  defp cancel_timer(%{timer_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | timer_ref: nil}
  end

  defp cpu_sup? do
    if Application.get_env(:infinity_one, :etop_use_cpu_sup),
      do: function_exported?(:cpu_sup, :start, 0),
      else: false
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
      |> maybe_set_file(opts)
    else
      Logger.info("Invalid opts")
      state
    end
  end

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

  defp valid_opts?(opts) do
    opts
    |> Keyword.keys()
    |> Enum.all?(&(&1 in @valid_opts))
  end
end
