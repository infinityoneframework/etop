defmodule Etop do
  @moduledoc """
  A Top like implementation for Elixir Applications.
  """
  use GenServer

  alias Etop.{Reader, Report}

  require Logger

  @name __MODULE__

  ###############
  # Public API

  def pause do
    GenServer.cast(@name, :pause)
  end

  @doc """
  Set Etop settings
  """
  def set_opts(opts) do
    if Enum.all?(Keyword.keys(opts), &(&1 in ~w(freq length debug file os_pid cores format)a)) do
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
      GenServer.cast(@name, :start)
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

    path = opts[:file]

    format =
      cond do
        val = opts[:format] -> val
        path && Path.extname(path) == ".exs" -> :exs
        true -> :text
      end

    util = if cpu_util?, do: CpuUtil.pid_util(os_pid), else: nil

    if node = opts[:node] do
      Node.connect(node)
    end

    # nprocs = :process_count |> :erlang.system_info() |> to_string()
    # memory = Enum.into(:erlang.memory(), %{})
    # runq: statistics(:run_queue)
    # util2 = CpuUtil.pid_util(os_pid)
    # {%{state | load: CpuUtil.calc_pid_util(util1, util2, cores)}, util2}
    {:ok,
     %{
       prev: nil,
       freq: opts[:freq] || 5000,
       length: opts[:length] || 10,
       debug: opts[:debug] || false,
       file: path,
       os_pid: os_pid,
       cores: cores,
       util: util,
       load: nil,
       format: format,
       halted: Keyword.get(opts, :halted, false),
       timer_ref: nil,
       cpu_util?: cpu_util?,
       node: opts[:node],
       info_map: nil,
       list: nil,
       stats: nil,
       total: 0
     }}
  end

  # def cpu_util(fun, args, true), do: apply(CpuUtil, fun, args)

  # def cpu_util(_, _, _), nil

  def handle_call(:status, _, state) do
    reply(state, Map.delete(state, :prev))
  end

  def handle_call(:status!, _, state) do
    reply(state, state)
  end

  def handle_call(:start, _, %{halted: true} = state) do
    reply(start_timer(%{state | halted: false}, 1000), :ok)
  end

  def handle_call(:start, _, state) do
    reply(state, :not_halted)
  end

  def handle_call(:pause, _, %{halted: true} = state) do
    reply(state, :not_halted)
  end

  def handle_call(:pause, _, state) do
    reply(cancel_timer(%{state | halted: true}), :ok)
  end

  def handle_cast({:set_opts, opts}, state) do
    state = Enum.reduce(opts, state, fn {k, v}, state -> Map.put(state, k, v) end)
    noreply(state)
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info({:result, stats}, state) do
    Logger.debug(fn -> "handle_info :result" end)
    # IO.inspect(stats, label: ":result stats")
    # Process the the main data and wait for info event {:info_response, info_map}
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

  # def handle_info({:info_response, info_map}, state) do
  #   Logger.debug(fn -> "handle_info :info_response" end)
  #   # We have all the data collected now. Time to report it.
  #   Report.handle_report(state, info_map)
  #   noreply(state)
  # end

  def handle_info(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_info(event, state) do
    IO.inspect(event, label: "handle_info")
    # silently ignore unhandled info messages
    noreply(state)
  end

  def terminate(reason, state) do
    cancel_timer(state)
    IO.inspect(reason, label: "terminate")
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

  defp start_timer(%{freq: interval} = state) do
    start_timer(state, interval)
  end

  defp start_timer(state, interval) when is_integer(interval) do
    %{state | timer_ref: Process.send_after(self(), :collect, interval)}
  end

  defp reply(%{} = state, reply), do: {:reply, reply, state}
  defp reply(state, _), do: raise("invalid state: #{inspect(state)}")

  defp noreply(%{} = state), do: {:noreply, state}
  defp noreply(state), do: raise("invalid state: #{inspect(state)}")
end
