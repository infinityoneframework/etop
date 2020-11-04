defmodule Etop.Watcher do
  @moduledoc """
  Etop Monitor Helpers.

  Setup Etop monitors for handling high CPU usage and process high message queue
  length reporting.

  ## Monitors

  ### High CPU monitor

  This monitor does the following:

  * Turns on reporting when the CPU usage exceeds 75% and calls the notify function.
  * Turns off the reporting when the CPU usage drops below 50%.

  The `notify` function can be overridden were it can implement a custom handler that
  can send an email, post a message to a messaging application, etc.

  ### Message Queue Length monitor

  This monitor does the following:

  * Calls notify when the length exceeds (1_500) messages.
  * Calls notify when the same process exceeding (1_500) messages once its
    length drops below (1_050) messages
  * Kills the process if the message queue length exceeds (20_000) messages and calls notify.

  ## Configuration

  The following can be configured with `Application.put_env(:infinity_one, option, value):

  * `:etop_msg_q_stop_limit` (20_000) - when to kill the process
  * `:etop_msg_q_notify_limit` (1_500) - when to notify
  * `:etop_msg_q_notify_lower_limit` (1_000) - When the monitor callback is called
  * `:etop_reporting_enable_limit` (75.0) - when to enable reporting
  * `:etop_reporting_disable_limit` (50.0) - when to disable reporting
  * `:etop_reporting_notify_lower_limit` (10.0) - when to reset the notification state

  ## Limitations

  * The CPU utilization monitor aggressively takes over the Etop reporting setting.
    This means that you can't see/log the Etop data unless the :etop_reporting_enable_limit
    is exceeded.
  """
  defmacro __using__(_opts \\ []) do
    quote do
      use GenServer

      import unquote(__MODULE__)

      require Logger

      @name __MODULE__

      @doc """
      Test if the monitor server is running.
      """
      @spec alive?() :: boolean()
      def alive?, do: if(pid = Process.whereis(@name), do: Process.alive?(pid), else: false)

      @doc """
      Start the Etop monitors.

      Starts the Agent and installs the Etop monitors.

      ## Options

      * reporting (true) - Don't disable Etop.reporting when false.
      * msg_q_stop_limit: msg_q_stop_limit(),
      * msg_q_notify_limit: msg_q_notify_limit(),
      * msg_q_notify_lower_limit: msg_q_notify_lower_limit(),
      * reporting_enable_limit: reporting_enable_limit(),
      * reporting_disable_limit: reporting_disable_limit(),
      * reporting_notify_lower_limit: reporting_notify_lower_limit(),
      * no_reporting (false) - don't enable Etop.reporting when true
      """
      @spec start(keyword()) :: any()
      def start(opts \\ []) do
        GenServer.start(__MODULE__, opts, name: @name)
      end

      @doc """
      Start the Etop monitors.
      """
      @spec start_link(keyword()) :: any()
      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: @name)
      end

      @doc """
      Add the monitors.
      """
      @spec add_monitors() :: none()
      def add_monitors do
        GenServer.cast(@name, :add_monitors)
      end

      @doc """
      The callback for the load monitor.
      """
      @spec load_callback(any(), any(), map()) :: any()
      def load_callback(info, value, state) do
        GenServer.call(@name, {:load_callback, info, value, state})
      end

      @doc """
      The process message queue length monitor callback.
      """
      @spec message_queue_callback(any(), any(), map()) :: any()
      def message_queue_callback(info, value, state) do
        GenServer.call(@name, {:message_queue_callback, info, value, state})
      end

      @doc """
      Stop the Etop monitors.

      Stops the EtopHelpers Agent and removes the monitors.
      """
      @spec stop() :: no_return()
      def stop do
        GenServer.cast(@name, :stop)
        etop().remove_monitors()
      end

      @doc """
      Set a key on the servers state.
      """
      @spec set_opts(any(), any()) :: none()
      def set_opts(key, value) do
        GenServer.cast(@name, {:set_opts, [{key, value}]})
      end

      @doc """
      Set a list of server's state keys.
      """
      @spec set_opts(keyword()) :: none()
      def set_opts(opts) when is_list(opts) do
        GenServer.cast(@name, {:set_opts, opts})
      end

      @doc """
      Get the state from the EtopHelpers Agent.
      """
      @spec get() :: map()
      def get, do: GenServer.call(@name, :get)

      @doc """
      Get the value of a key from the EtopHelpers Agent.
      """
      @spec get(any()) :: any()
      def get(key), do: GenServer.call(@name, {:get, key})

      @doc """
      Set a key in the EtopHelpers Agent.
      """
      def put(key), do: GenServer.cast(@name, {:put, key})

      @doc """
      Clear the state of the EtopHelpres Agent.
      """
      @type clear() :: no_return()
      def clear, do: GenServer.cast(@name, :clear)

      @doc """
      Remove a key from the EtopHelpers Agent.
      """
      @spec clear(any()) :: no_return()
      def clear(key), do: GenServer.cast(@name, {:clear, key})

      @doc """
      Get the Server's state.
      """
      @spec status() :: map()
      def status, do: GenServer.call(@name, :status)

      @spec init(keyword()) :: {:ok, map()}
      def init(opts) do
        {etop_opts, opts} = Keyword.pop(opts, :etop_opts, [])
        unless etop().alive?(), do: etop().start(etop_opts)
        send(self(), :initialize)
        {:ok, initial_state(opts)}
      end

      #############
      # handle_info

      def handle_info(:initialize, state) do
        {:noreply, add_monitors(state)}
      end

      ##############
      # handle_cast

      def handle_cast(:clear, state) do
        {:noreply, clear_keys(state)}
      end

      def handle_cast({:clear, key}, state) do
        {:noreply, clear_key(state, key)}
      end

      def handle_cast({:put, key}, state) do
        {:noreply, put_key(state, key)}
      end

      def handle_cast({:set_opts, opts}, state) do
        {:noreply, Map.merge(state, Enum.into(opts, %{}))}
      end

      def handle_cast(:stop, state) do
        {:stop, :normal, state}
      end

      ##############
      # handle_call

      def handle_call(:get, _, state) do
        {:reply, state.set, state}
      end

      def handle_call({:get, key}, _, state) do
        {:reply, get_key(state, key), state}
      end

      def handle_call(:status, _, state) do
        {:reply, state, state}
      end

      def handle_call({:load_callback, info, value, etop}, _, state) do
        handle_load_callback(state, info, value, etop)
      end

      def handle_call({:message_queue_callback, info, value, etop}, _, state) do
        handle_message_queue_callback(state, info, value, etop)
      end

      ########################
      # load_callback handlers

      defp handle_load_callback(state, info, value, etop) do
        notify_pid(state, info, value, etop)

        {etop, state} =
          cond do
            value >= state.reporting_enable_limit ->
              # 75.0 default
              handle_load_reporting_enable(state, info, value, etop)

            value <= state.reporting_notify_lower_limit ->
              # 10.0 default
              handle_load_reporting_lower_limit(state, info, value, etop)

            value <= state.reporting_disable_limit ->
              # 50.0 default
              handle_load_reporting_disable(state, info, value, etop)

            true ->
              handle_load_default(state, info, value, etop)
          end

        {:reply, etop, state}
      end

      def handle_load_reporting_enable(state, _info, value, etop) do
        {set_reporting(state, etop),
         notify(state, :load, "Etop high CPU usage: #{inspect(value)}")}
      end

      def handle_load_reporting_lower_limit(state, _info, value, etop) do
        {clear_reporting(state, etop),
         notify_disable(state, :load, "Etop high CPU usage resolved: #{inspect(value)}")}
      end

      def handle_load_reporting_disable(state, _info, value, etop) do
        # turn off reporting if its on and we have not overridden it
        # 50.0 default
        {etop, notify_disable(state, :load, "Etop high CPU usage resolved: #{inspect(value)}")}
      end

      def handle_load_default(state, _info, _value, etop) do
        {etop, state}
      end

      ########################
      # load_callback handlers

      defp handle_message_queue_callback(state, info, value, etop) do
        notify_pid(state, info, value, etop)

        {etop, state} =
          cond do
            value >= state.msg_q_stop_limit ->
              # :etop_msg_q_stop_limit, 20_000
              handle_msg_q_stop_limit(state, info, value, etop)

            value >= state.msg_q_notify_limit ->
              # :etop_msg_q_notify_limit, 1_500
              handle_msg_q_limit(state, info, value, etop)

            value <= state.msg_q_notify_lower_limit + 50 ->
              # :etop_msg_q_notify_lower_limit, 1_000
              handle_msg_q_lower_limit(state, info, value, etop)

            true ->
              handle_msg_q_default(state, info, value, etop)
          end

        {:reply, etop, state}
      end

      def handle_msg_q_stop_limit(state, info, value, etop) do
        # :etop_msg_q_stop_limit, 20_000
        pid = info[:pid]

        notify(
          state,
          "Killing process with high msg_q length: #{inspect(value)}, pid: #{inspect(pid)}, info: #{
            inspect(info)
          }"
        )

        Process.exit(pid, :kill)

        {clear_proc_r(etop, pid), clear_key(state, {:msgq, pid})}
      end

      def handle_msg_q_limit(state, info, value, etop) do
        # :etop_msg_q_notify_limit, 1_500
        pid = info[:pid]

        {set_reporting(state, set_proc_r(etop, pid)),
         notify(
           state,
           {:msgq, pid},
           "High message queue length: #{inspect(value)}, pid: #{inspect(pid)}"
         )}
      end

      def handle_msg_q_lower_limit(state, info, value, etop) do
        # :etop_msg_q_notify_lower_limit, 1_000
        pid = info[:pid]

        {clear_reporting(state, clear_proc_r(etop, pid)),
         notify_disable(
           state,
           {:msgq, pid},
           "High Message queue alert resolved, pid: #{inspect(pid)}"
         )}
      end

      def handle_msg_q_default(state, _info, _value, etop) do
        {etop, state}
      end

      defp set_proc_r(etop, pid) do
        proc_r = etop[:proc_r] || MapSet.new()
        Map.put(etop, :proc_r, MapSet.put(proc_r, pid))
      end

      defp clear_proc_r(etop, pid) do
        set =
          &if(MapSet.size(&1) == 0,
            do: Map.delete(etop, :proc_r),
            else: Map.put(etop, :proc_r, &1)
          )

        case etop[:proc_r] do
          nil -> etop
          proc_r -> set.(MapSet.delete(proc_r, pid))
        end
      end

      @doc """
      Add the Etop monitors.
      """
      @spec add_monitors(map()) :: no_return()
      def add_monitors(state) do
        monitors = etop().monitors()

        unless Enum.find(monitors, find_monitor(:summary, [:load, :total], 0.0)) do
          add_reporting_monitor(state)
        end

        unless Enum.find(
                 monitors,
                 find_monitor(:process, :message_queue_len, state.msg_q_notify_lower_limit)
               ) do
          add_message_queue_monitor(state)
        end

        state
      end

      @doc """
      Add the CPU utilization monitor.
      """
      def add_reporting_monitor(state) do
        etop().add_monitor(
          :summary,
          [:load, :total],
          load_threshold(state),
          {__MODULE__, :load_callback}
        )

        state
      end

      @doc """
      Add the message queue length monitor.
      """
      def add_message_queue_monitor(state) do
        etop().add_monitor(
          :process,
          :message_queue_len,
          msgq_threshold(state),
          {__MODULE__, :message_queue_callback}
        )

        state
      end

      @doc """
      Create the load threshold comparator/2 function.
      """
      @spec load_threshold(map()) :: (number(), map() -> boolean())
      def load_threshold(state) do
        %{reporting_enable_limit: limit1, reporting_notify_lower_limit: limit2} = state
        &(&1 >= limit1 or (&2.reporting and &1 <= limit2))
      end

      @doc """
      Create the msgq threshold comparator/3 function.
      """
      @spec msgq_threshold(map()) :: (number(), map() -> boolean())
      def msgq_threshold(%{msg_q_notify_limit: limit} = state) do
        r_test = &(!!&1[:proc_r] and MapSet.member?(&1[:proc_r], &2[:pid]))
        &(&1 >= limit or r_test.(&3, &2))
      end

      @spec initial_state(keyword()) :: map()
      def initial_state(opts \\ []) do
        [
          set: MapSet.new(),
          reporting: true,
          msg_q_stop_limit: msg_q_stop_limit(),
          msg_q_notify_limit: msg_q_notify_limit(),
          msg_q_notify_lower_limit: msg_q_notify_lower_limit(),
          reporting_enable_limit: reporting_enable_limit(),
          reporting_disable_limit: reporting_disable_limit(),
          reporting_notify_lower_limit: reporting_notify_lower_limit(),
          notify_pid: nil,
          no_reporting: false
        ]
        |> Keyword.merge(opts)
        |> Enum.into(%{})
      end

      #############
      # Private

      defp notify_pid(%{notify_pid: pid} = state, info, value, etop) do
        if is_pid(pid), do: send(pid, {:etop_monitor, {info, value, etop}})
      end

      defp etop, do: Application.get_env(:etop, :etop, Etop)

      defp get_key(state, key), do: MapSet.member?(state.set, key)

      defp put_key(state, key), do: %{state | set: MapSet.put(state.set, key)}

      defp clear_key(state, key), do: %{state | set: MapSet.delete(state.set, key)}

      defp clear_keys(state), do: %{state | set: MapSet.new()}

      defp set_reporting(%{no_reporting: false}, etop), do: %{etop | reporting: true}
      defp set_reporting(_, etop), do: etop
      defp clear_reporting(%{reporting: true}, etop), do: %{etop | reporting: false}
      defp clear_reporting(_, etop), do: etop

      defp find_monitor(type, fields, value) do
        fn
          {^type, ^fields, ^value, _} -> true
          _ -> false
        end
      end

      def notify(state, key, message) do
        if get_key(state, key) do
          state
        else
          state
          |> put_key(key)
          |> notify(message)
        end
      end

      def notify(state, message) do
        level =
          case state[:notify_log] do
            true -> :info
            level when level in ~w(error warn info debug)a -> level
            _ -> nil
          end

        if level, do: Logger.log(level, message)
        state
      end

      def notify_disable(state, key, message) do
        if get_key(state, key) do
          state
          |> clear_key(key)
          |> notify(message)
        else
          state
        end
      end

      def msg_q_stop_limit, do: Application.get_env(:etop, :etop_msg_q_stop_limit, 20_000)
      def msg_q_notify_limit, do: Application.get_env(:etop, :etop_msg_q_notify_limit, 1_500)

      def msg_q_notify_lower_limit,
        do: Application.get_env(:etop, :etop_msg_q_notify_lower_limit, 1_000)

      def reporting_enable_limit,
        do: Application.get_env(:etop, :etop_reporting_enable_limit, 75.0)

      def reporting_disable_limit,
        do: Application.get_env(:etop, :etop_reporting_disable_limit, 50.0)

      def reporting_notify_lower_limit,
        do: Application.get_env(:infinity_one, :etop_reporting_notify_lower_limit, 10.0)

      defoverridable(
        handle_load_reporting_enable: 4,
        handle_load_reporting_lower_limit: 4,
        handle_load_reporting_disable: 4,
        handle_load_default: 4,
        handle_msg_q_stop_limit: 4,
        handle_msg_q_limit: 4,
        handle_msg_q_lower_limit: 4,
        handle_msg_q_default: 4,
        initial_state: 1,
        load_threshold: 1,
        msgq_threshold: 1,
        msg_q_notify_limit: 0,
        msg_q_notify_lower_limit: 0,
        msg_q_stop_limit: 0,
        notify: 2,
        notify: 3,
        notify_disable: 3,
        reporting_disable_limit: 0,
        reporting_enable_limit: 0,
        reporting_notify_lower_limit: 0,
        start: 0,
        start: 1,
        start_link: 0,
        start_link: 1
      )
    end
  end
end
