defmodule EtopTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias EtopTest.Callbacks

  doctest Etop

  @tmp_path "test/tmp"
  @exs_log_path Path.join(@tmp_path, "log.exs")

  setup do
    on_exit(fn ->
      Etop.stop()
      Process.sleep(20)
    end)

    :ok
  end

  def setup_start_paused(_) do
    Etop.start()
    Etop.pause()

    :ok
  end

  def setup_log_exs(_) do
    {:ok, data: Etop.load("test/fixtures/log.exs")}
  end

  def setup_logging(_) do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    Etop.start(file: @exs_log_path, first_interval: 10, interval: 100)
    Process.sleep(20)

    :ok
  end

  describe "basic" do
    test "Starts" do
      {:ok, pid} = Etop.start()
      assert is_pid(pid)
      Etop.stop()
      Process.sleep(100)
    end

    test "Status" do
      {:ok, _pid} = Etop.start()
      assert is_map(Etop.status())
    end

    test "reporting/1" do
      Etop.start()
      Etop.pause()
      assert Etop.reporting(false) == :ok
      assert Etop.reporting(false) == :not_reporting
      assert Etop.reporting(true) == :ok
      assert Etop.reporting(true) == :already_reporting
    end

    test "init single monitor" do
      callback = &IO.inspect({&1, &2, &3})
      monitor = {:summary, [:load, :total], 10, callback}
      {:ok, state} = Etop.init(monitors: monitor)
      assert state.monitors == [monitor]
    end
  end

  describe "options" do
    setup [:setup_start_paused]

    test "sort options" do
      # ~w(memory msgq reds reds_diff status default)a do
      Etop.set_opts(sort: :default)
      assert Etop.status().sort == :reductions_diff

      Etop.set_opts(sort: :memory)
      assert Etop.status().sort == :memory

      Etop.set_opts(sort: :msgq)
      assert Etop.status().sort == :message_queue_len

      Etop.set_opts(sort: :reds)
      assert Etop.status().sort == :reductions

      Etop.set_opts(sort: :reds_diff)
      assert Etop.status().sort == :reductions_diff

      Etop.set_opts(sort: :status)
      assert Etop.status().sort == :status
    end

    test "file" do
      Etop.set_opts(file: "test")
      assert Etop.status() |> Map.take([:file, :format]) == %{file: "test", format: :text}
    end

    test "monitor/5" do
      callback = fn _, _, state -> state end
      %{monitors: monitors} = Etop.monitor(%{monitors: nil}, :summary, [:load, :total], 10, callback)

      assert monitors == [
        {:summary, [:load, :total], 10, callback}
      ]
    end

    test "file exs" do
      Etop.set_opts(file: "test.exs")
      assert Etop.status() |> Map.take([:file, :format]) == %{file: "test.exs", format: :exs}
    end

    test "debug" do
      Etop.stop()
      Process.sleep(100)
      Etop.start(debug: true)
      Etop.pause()
      assert Etop.status().debug

      Etop.continue(debug: false)
      refute Etop.status().debug
    end

    test "monitor/4" do
      callback = &{&1, &2, &3}
      Etop.monitor(:process, :reductions, 10_000, callback)
      assert Etop.status().monitors == [{:process, :reductions, 10_000, callback}]
    end

    test "add_monitor/4" do
      callback = &{&1, &2, &3}
      callback1 = &IO.inspect({&1, &2, &3})
      Etop.monitor(:process, :reductions, 10_000, callback)
      Etop.add_monitor(:summary, [:load, :user], 50.0, callback1)

      assert Etop.status().monitors == [
               {:summary, [:load, :user], 50.0, callback1},
               {:process, :reductions, 10_000, callback}
             ]
    end

    test "remove_monitor/3" do
      callback = &{&1, &2, &3}
      callback1 = &IO.inspect({&1, &2, &3})
      Etop.monitor(:process, :reductions, 10_000, callback)
      Etop.add_monitor(:summary, [:load, :user], 50.0, callback1)
      Etop.remove_monitor(:summary, [:load, :user], 50.0)

      assert Etop.status().monitors == [
               {:process, :reductions, 10_000, callback}
             ]

      assert Etop.remove_monitor(:summary, [:load, :sys], 10) == :not_found
    end

    test "monitor clear" do
      callback = &{&1, &2, &3}
      Etop.monitor(:process, :reductions, 10_000, callback)
      Etop.remove_monitors()
      assert Etop.monitors() == []
    end

    test "set_opts monitors" do
      callback = &{&1, &2, &3}
      Etop.set_opts(monitors: [{:summary, [:load, :total], 10.0, callback}])
      assert Etop.monitors() == [{:summary, [:load, :total], 10.0, callback}]
    end

    test "set_opts monitors invalid" do
      bad_callback = &{&1, &2}

      assert capture_log(fn ->
        %{monitors: nil} = Etop.monitor(%{monitors: nil}, :summary, [:load, :total], 10.0, bad_callback)
      end) =~ "Invalid opts"
    end
  end

  describe "public api" do
    setup [:setup_start_paused]

    test "status" do
      status = Etop.status()
      refute Map.has_key?(status.stats, :procs)
    end

    test "status!" do
      status = Etop.status!()
      assert Map.has_key?(status.stats, :procs)
    end

    test "load without file" do
      assert Etop.load() == {:error, :invalid_file}
    end

    test "pause when paused" do
      assert Etop.pause() == :already_halted
    end
  end

  describe "integration" do
    setup [:setup_logging]

    test "first iteration" do
      Etop.pause()

      [%{summary: summary, processes: processes}] = data = Etop.load()

      assert length(data) == 1
      assert data |> hd() |> Map.keys() == [:processes, :summary]
      assert length(processes) == 10
      assert summary.node == "nonode@nohost"
    end

    test "pause and continue" do
      Etop.pause()
      assert Etop.status().interval == 100
      Etop.continue()
      Process.sleep(110)
      Etop.pause()

      data = Etop.load()
      assert length(data) >= 2
    end

    test "continue when not halted" do
      assert Etop.continue() == :not_halted
    end

    test "start when started" do
      pid = Process.whereis(Etop)
      assert Etop.start() == {:error, {:already_started, pid}}
    end

    test "ignores collect when halted" do
      Etop.pause()
      send(Etop, :collect)
      Process.sleep(110)
      assert (Etop.load() |> length()) in [1, 2]
    end

    test "invalid event" do
      Etop.pause()
      status = Etop.status!()
      send(Etop, :unknown)
      assert Etop.status!() == status
    end
  end

  describe "GenServer helpers" do
    test "reply/2" do
      state = %{test: 1}
      assert Etop.reply(state, :ok) == {:reply, :ok, state}

      assert_raise RuntimeError, "invalid state: nil", fn ->
        Etop.reply(nil, :ok)
      end
    end

    test "noreply/1" do
      state = %{test: 1}
      assert Etop.noreply(state) == {:noreply, state}

      assert_raise RuntimeError, "invalid state: nil", fn ->
        Etop.noreply(nil)
      end
    end
  end

  describe "monitor" do
    test "summary:load:total" do
      Etop.start(first_interval: 10, interval: 100, reporting: false)
      Callbacks.start()
      refute Etop.status().reporting
      assert capture_log(fn ->
        Callbacks.add_callback()
        Process.sleep(150)
      end) =~ "match 1"
      assert Etop.status().reporting
    end
  end

  describe "common" do
    setup [:setup_log_exs]

    test "sort msgq", %{data: data} do
      expected = %{
        processes: [
          %{
            fun: ":erl_prim_loader.loop/3",
            memory: 426_508,
            msg_q: 0,
            name: ":erlang.apply/2",
            percent: 29.28,
            pid: '<0.9.0>',
            reds_diff: 921_464,
            reductions: 921_464,
            state: :waiting
          },
          %{
            fun: "IEx.Evaluator.loop/1",
            memory: 1_115_316,
            msg_q: 0,
            name: "IEx.Evaluator.init/4",
            percent: 27.83,
            pid: '<0.226.0>',
            reds_diff: 875_941,
            reductions: 875_941,
            state: :waiting
          },
          %{
            fun: ":code_server.loop/1",
            memory: 196_980,
            msg_q: 10,
            name: ":erlang.apply/2",
            percent: 7.69,
            pid: '<0.49.0>',
            reds_diff: 241_976,
            reductions: 241_976,
            state: :waiting
          },
          %{
            fun: ":group.more_data/6",
            memory: 8_011_832,
            msg_q: 0,
            name: ":group.server/3",
            percent: 6.56,
            pid: '<0.64.0>',
            reds_diff: 206_407,
            reductions: 206_407,
            state: :waiting
          },
          %{
            fun: ":user_drv.server_loop/6",
            memory: 109_396,
            msg_q: 5,
            name: ":user_drv.server/2",
            percent: 5.46,
            pid: '<0.62.0>',
            reds_diff: 172_007,
            reductions: 172_007,
            state: :waiting
          },
          %{
            fun: ":erts_code_purger.wait_for_request/0",
            memory: 20880,
            msg_q: 0,
            name: ":erts_code_purger.start/0",
            percent: 5.22,
            pid: '<0.1.0>',
            reds_diff: 164_253,
            reductions: 164_253,
            state: :waiting
          },
          %{
            fun: ":erts_literal_area_collector.msg_loop/4",
            memory: 2688,
            msg_q: 0,
            name: ":erts_literal_area_collector.start/",
            percent: 5.01,
            pid: '<0.2.0>',
            reds_diff: 157_751,
            reductions: 157_751,
            state: :waiting
          },
          %{
            fun: ":gen_server.loop/7",
            memory: 264_396,
            msg_q: 0,
            name: ":application_controller.start/1",
            percent: 4.89,
            pid: '<0.43.0>',
            reds_diff: 153_876,
            reductions: 153_876,
            state: :waiting
          },
          %{
            fun: ":gen_server.loop/7",
            memory: 426_596,
            msg_q: 4,
            name: ":file_server.init/1",
            percent: 3.59,
            pid: '<0.57.0>',
            reds_diff: 112_924,
            reductions: 112_924,
            state: :waiting
          },
          %{
            fun: ":disk_log.loop/1",
            memory: 264_300,
            msg_q: 0,
            name: ":disk_log.init/2",
            percent: 1.22,
            pid: '<0.79.0>',
            reds_diff: 38389,
            reductions: 38389,
            state: :waiting
          }
        ],
        summary: %{
          load: %{cpu: 2.9, nprocs: "92", runq: 0},
          memory: %{
            atom: 512_625,
            atom_used: 501_465,
            binary: 218_688,
            code: 10_318_069,
            ets: 797_536,
            processes: 21_886_368,
            processes_used: 21_885_976,
            system: 19_859_792,
            total: 41_746_160
          },
          node: "nonode@nohost",
          time: "08:36:11"
        }
      }

      item = hd(data)
      assert item == expected
    end
  end

  defmodule Callbacks do
    require Logger
    use GenServer
    @name __MODULE__
    def start, do: GenServer.start(__MODULE__, [notify_log: true, no_reporting: true], name: @name)
    def stop, do: GenServer.cast(@name, :stop)
    def callback(info, value, etop), do: GenServer.call(@name, {:callback, info, value, etop})
    def add_callback, do: GenServer.cast(@name, :add_callback)

    def init(_), do: {:ok, nil}
    def handle_cast(:stop, state), do: {:stop, :normal, state}
    def handle_cast(:add_callback, state) do
      Etop.add_monitor(:summary, [:load, :total], 0.0, {__MODULE__, :callback})
      {:noreply, state}
    end
    def handle_call({:callback, _info, value, etop}, _, state) do
      Logger.info("match 1 #{inspect value}")
      {:reply, %{etop | reporting: true}, state}
    end
  end
end
