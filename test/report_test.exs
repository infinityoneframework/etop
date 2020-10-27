defmodule Etop.ReportTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Etop.Report

  doctest Etop.Report

  @log_path "test/fixtures/log.exs"

  setup do
    {:ok, data: data1()}
  end

  def setup_log_exs(_) do
    {:ok, data: Etop.load(@log_path)}
  end

  test "create_report/3", %{data: data} do
    total = data.procs |> Enum.map(fn {_, item} -> item[:reductions] end) |> Enum.sum()

    %{processes: processes, summary: summary} = Report.create_report(data.procs, total, data)

    assert processes == [
             %{
               fun: ":application_master.loop_it/4",
               memory: {:memory, 8888},
               msg_q: 0,
               name: ":application_master.start_it/4",
               percent: 37.83,
               pid: '<0.141.0>',
               reds_diff: 300,
               reductions: 338,
               state: :waiting
             },
             %{
               fun: ":gen_server.loop/7",
               memory: {:memory, 7104},
               msg_q: 0,
               name: ":supervisor.Elixir.Supervisor.Defau",
               percent: 50.44,
               pid: '<0.142.0>',
               reds_diff: 400,
               reductions: 455,
               state: :waiting
             }
           ]

    assert summary.load == %{cpu: "-", nprocs: "2", runq: 0}

    assert summary.memory == %{
             atom: 471_657,
             atom_used: 465_552,
             binary: 359_984,
             code: 9_115_010,
             ets: 627_712,
             processes: 122_074_832,
             processes_used: 122_073_768,
             system: 18_647_328,
             total: 140_722_160
           }

    assert summary.time
  end

  test "load invalid exs file" do
    path = "/tmp/nofile#{:rand.uniform(100_000)}.exs"
    File.write!(path, ":a = 1")
    assert Report.load(path) == {:error, %MatchError{term: 1}}
    File.rm(path)
  end

  describe "load" do
    setup [:setup_log_exs]

    test "max/0" do
      capture_io(fn ->
        assert Report.max().summary == %{
                 load: %{cpu: 9.0, nprocs: "94", runq: 0},
                 memory: %{
                   atom: 512_625,
                   atom_used: 501_973,
                   binary: 273_208,
                   code: 10_350_130,
                   ets: 799_808,
                   processes: 56_185_544,
                   processes_used: 56_181_800,
                   system: 19_972_256,
                   total: 76_157_800
                 },
                 node: "nonode@nohost",
                 time: "08:36:21"
               }
      end)
    end

    test "max/1" do
      capture_io(fn ->
        assert @log_path |> Report.load() |> Report.max() |> Map.get(:summary) == %{
                 load: %{cpu: 9.0, nprocs: "94", runq: 0},
                 memory: %{
                   atom: 512_625,
                   atom_used: 501_973,
                   binary: 273_208,
                   code: 10_350_130,
                   ets: 799_808,
                   processes: 56_185_544,
                   processes_used: 56_181_800,
                   system: 19_972_256,
                   total: 76_157_800
                 },
                 node: "nonode@nohost",
                 time: "08:36:21"
               }
      end)
    end

    test "plot_cpu" do
      expected =
        """

                               CPU Utilization
                               ---------------
          10% |
           9% |           *
           8% |             * *
           7% |                 *
           6% |                   *
           5% |
           4% |         *
           3% | *
           2% |   * *                 *   *       *     *
           1% |       *             *   *   * * *   * *   * * *
           0% |
              +-------------------+-------------------+----------
                              08:36:31            08:36:52
        """
        |> String.split("\n")

      assert capture_io(fn ->
               @log_path |> Report.load() |> Report.plot_cpu()
               assert true
             end)
             |> String.split("\n")
             |> Enum.map(&String.trim_trailing/1) == expected

      # capture_io(fn ->
      #   @log_path |> Report.load() |> Report.plot_cpu()
      #   assert true
      # end)
      # |> IO.puts()
    end

    test "plot_memory" do
      expected =
        """

                                 Memory Usage
                                 ------------
         162MB |                                 *
         153MB |                               *
         144MB |                           * *               * *
         135MB |                   * *   *           * *   *
         126MB |                 *     *           *     *
         117MB |               *
         108MB |
          99MB |
          90MB |
          81MB |             *
          72MB |       *   *
          63MB |   * *   *
          54MB |
          45MB |
          36MB | *
           0MB |
               +-------------------+-------------------+----------
                              08:36:31            08:36:52
        """
        |> String.split("\n")

      assert capture_io(fn ->
               @log_path |> Report.load() |> Report.plot_memory()
               assert true
             end)
             |> String.split("\n")
             |> Enum.map(&String.trim_trailing/1) == expected
    end

    test "print/1 entry" do
      expected = [
        "====================================================================================================================================",
        "nonode@nohost                                                                                                               08:36:11",
        "Load:  cpu     2.9%                      Memory:  total           41746160     binary    218688",
        "       procs     92                               processes       21886368     code    10318069",
        "       runq       0                                atom             512625      ets      797536",
        "",
        "Pid                            Name or Initial Func  Percent          Reds    Memory MsgQ      State Current Function",
        "------------------------------------------------------------------------------------------------------------------------------------",
        "<0.9.0>                             :erlang.apply/2    29.28        921464    426508    0    waiting :erl_prim_loader.loop/3",
        "<0.226.0>                      IEx.Evaluator.init/4    27.83        875941   1115316    0    waiting IEx.Evaluator.loop/1",
        "<0.49.0>                            :erlang.apply/2     7.69        241976    196980   10    waiting :code_server.loop/1",
        "<0.64.0>                            :group.server/3     6.56        206407   8011832    0    waiting :group.more_data/6",
        "<0.62.0>                         :user_drv.server/2     5.46        172007    109396    5    waiting :user_drv.server_loop/6",
        "<0.1.0>                   :erts_code_purger.start/0     5.22        164253     20880    0    waiting :erts_code_purger.wait_for_request/0",
        "<0.2.0>         :erts_literal_area_collector.start/     5.01        157751      2688    0    waiting :erts_literal_area_collector.msg_loop/4",
        "<0.43.0>            :application_controller.start/1     4.89        153876    264396    0    waiting :gen_server.loop/7",
        "<0.57.0>                        :file_server.init/1     3.59        112924    426596    4    waiting :gen_server.loop/7",
        "<0.79.0>                           :disk_log.init/2     1.22         38389    264300    0    waiting :disk_log.loop/1",
        "====================================================================================================================================",
        "",
        "",
        ""
      ]

      assert capture_io(fn ->
               @log_path |> Report.load() |> hd() |> Report.print()
             end)
             |> String.split("\n")
             |> Enum.map(&String.trim_trailing/1) == expected
    end

    test "print/1 entrys" do
      expected = [
        "====================================================================================================================================",
        "nonode@nohost                                                                                                               08:36:11",
        "Load:  cpu     2.9%                      Memory:  total           41746160     binary    218688",
        "       procs     92                               processes       21886368     code    10318069",
        "       runq       0                                atom             512625      ets      797536",
        "",
        "Pid                            Name or Initial Func  Percent          Reds    Memory MsgQ      State Current Function",
        "------------------------------------------------------------------------------------------------------------------------------------",
        "<0.9.0>                             :erlang.apply/2    29.28        921464    426508    0    waiting :erl_prim_loader.loop/3",
        "<0.226.0>                      IEx.Evaluator.init/4    27.83        875941   1115316    0    waiting IEx.Evaluator.loop/1",
        "<0.49.0>                            :erlang.apply/2     7.69        241976    196980   10    waiting :code_server.loop/1",
        "<0.64.0>                            :group.server/3     6.56        206407   8011832    0    waiting :group.more_data/6",
        "<0.62.0>                         :user_drv.server/2     5.46        172007    109396    5    waiting :user_drv.server_loop/6",
        "<0.1.0>                   :erts_code_purger.start/0     5.22        164253     20880    0    waiting :erts_code_purger.wait_for_request/0",
        "<0.2.0>         :erts_literal_area_collector.start/     5.01        157751      2688    0    waiting :erts_literal_area_collector.msg_loop/4",
        "<0.43.0>            :application_controller.start/1     4.89        153876    264396    0    waiting :gen_server.loop/7",
        "<0.57.0>                        :file_server.init/1     3.59        112924    426596    4    waiting :gen_server.loop/7",
        "<0.79.0>                           :disk_log.init/2     1.22         38389    264300    0    waiting :disk_log.loop/1",
        "====================================================================================================================================",
        "",
        "",
        "====================================================================================================================================",
        "nonode@nohost                                                                                                               08:36:13",
        "Load:  cpu     1.5%                      Memory:  total           65486544     binary    254120",
        "       procs     92                               processes       45537024     code    10350130",
        "       runq       0                                atom             512625      ets      799808",
        "",
        "Pid                            Name or Initial Func  Percent          Reds    Memory MsgQ      State Current Function",
        "------------------------------------------------------------------------------------------------------------------------------------",
        "<0.449.0>                               Etop.init/1     95.7        103956  30485536    0    running Process.info/1",
        "<0.9.0>                             :erlang.apply/2     3.44          3742    426508    0    waiting :erl_prim_loader.loop/3",
        "<0.49.0>                            :erlang.apply/2     0.55           601    196980    0    waiting :code_server.loop/1",
        "<0.57.0>                        :file_server.init/1     0.11           119    426596    0    waiting :gen_server.loop/7",
        "<0.3.0>         :erts_dirty_process_signal_handler.     0.03            30      2688    0    waiting :erts_dirty_process_signal_handler.msg_loop/0",
        "<0.79.0>                           :disk_log.init/2      0.0             4    264324    0    waiting :disk_log.loop/1",
        "<0.46.0>             :application_master.start_it/4      0.0             2      6928    0    waiting :application_master.loop_it/4",
        "<0.91.0>             :application_master.start_it/4      0.0             2      2776    0    waiting :application_master.loop_it/4",
        "<0.115.0>       Mix.ProjectStack.-start_link/1-fun-      0.0             2     55132    0    waiting :gen_server.loop/7",
        "<0.51.0>                                :rpc.init/1      0.0             2      2820    0    waiting :gen_server.loop/7",
        "====================================================================================================================================",
        "",
        "",
        ""
      ]

      assert capture_io(fn ->
               @log_path |> Report.load() |> Enum.take(2) |> Report.print()
             end)
             |> String.split("\n")
             |> Enum.map(&String.trim_trailing/1) == expected
    end

    test "print/2 sort" do
      expected = [
        "====================================================================================================================================",
        "nonode@nohost                                                                                                               08:36:11",
        "Load:  cpu     2.9%                      Memory:  total           41746160     binary    218688",
        "       procs     92                               processes       21886368     code    10318069",
        "       runq       0                                atom             512625      ets      797536",
        "",
        "Pid                            Name or Initial Func  Percent          Reds    Memory MsgQ      State Current Function",
        "------------------------------------------------------------------------------------------------------------------------------------",
        "<0.49.0>                            :erlang.apply/2     7.69        241976    196980   10    waiting :code_server.loop/1",
        "<0.62.0>                         :user_drv.server/2     5.46        172007    109396    5    waiting :user_drv.server_loop/6",
        "<0.57.0>                        :file_server.init/1     3.59        112924    426596    4    waiting :gen_server.loop/7",
        "<0.79.0>                           :disk_log.init/2     1.22         38389    264300    0    waiting :disk_log.loop/1",
        "<0.43.0>            :application_controller.start/1     4.89        153876    264396    0    waiting :gen_server.loop/7",
        "<0.2.0>         :erts_literal_area_collector.start/     5.01        157751      2688    0    waiting :erts_literal_area_collector.msg_loop/4",
        "<0.1.0>                   :erts_code_purger.start/0     5.22        164253     20880    0    waiting :erts_code_purger.wait_for_request/0",
        "<0.64.0>                            :group.server/3     6.56        206407   8011832    0    waiting :group.more_data/6",
        "<0.226.0>                      IEx.Evaluator.init/4    27.83        875941   1115316    0    waiting IEx.Evaluator.loop/1",
        "<0.9.0>                             :erlang.apply/2    29.28        921464    426508    0    waiting :erl_prim_loader.loop/3",
        "====================================================================================================================================",
        "",
        "",
        ""
      ]

      assert capture_io(fn ->
               @log_path |> Report.load() |> hd() |> Report.print(sort: :msgq)
             end)
             |> String.split("\n")
             |> Enum.map(&String.trim_trailing/1) == expected
    end
  end

  defp data1,
    do: %{
      load: nil,
      memory: %{
        atom: 471_657,
        atom_used: 465_552,
        binary: 359_984,
        code: 9_115_010,
        ets: 627_712,
        processes: 122_074_832,
        processes_used: 122_073_768,
        system: 18_647_328,
        total: 140_722_160
      },
      nprocs: "2",
      runq: 0,
      util2:
        {:ok,
         "28691 (beam.smp) S 30901 28691 30901 34818 28691 4202496 23786 5818 0 0 106 19 0 0 20 0 28 0 250390882 3123240960 39321 18446744073709551615 4194304 7475860 140726907655760 140726907654096 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"},
      procs: procs1(),
      node: "nonode@nohost"
    }

  defp procs1,
    do: [
      {pid('<0.141.0>'),
       Enum.into(
         [
           memory: {:memory, 8888},
           reductions_diff: 300,
           current_function: {:application_master, :loop_it, 4},
           initial_call: {:application_master, :start_it, 4},
           status: :waiting,
           message_queue_len: 0,
           links: [pid('<0.140.0>'), pid('<0.142.0>')],
           dictionary: [],
           trap_exit: true,
           error_handler: :error_handler,
           priority: :normal,
           group_leader: pid('<0.140.0>'),
           total_heap_size: 986,
           heap_size: 376,
           stack_size: 5,
           reductions: 338,
           garbage_collection: [
             max_heap_size: %{error_logger: true, kill: true, size: 0},
             min_bin_vheap_size: 46422,
             min_heap_size: 233,
             fullsweep_after: 65535,
             minor_gcs: 1
           ],
           suspending: []
         ],
         %{}
       )},
      {pid('<0.142.0>'),
       Enum.into(
         [
           memory: {:memory, 7104},
           reductions_diff: 400,
           registered_name: Logger.Supervisor,
           current_function: {:gen_server, :loop, 7},
           initial_call: {:proc_lib, :init_p, 5},
           status: :waiting,
           message_queue_len: 0,
           links: [pid('<0.143.0>'), pid('<0.144.0>')],
           dictionary: [
             "$ancestors": [pid('<0.141.0>')],
             "$initial_call": {:supervisor, Supervisor.Default, 1}
           ],
           trap_exit: true,
           error_handler: :error_handler,
           priority: :normal,
           group_leader: pid('<0.140.0>'),
           total_heap_size: 752,
           heap_size: 376,
           stack_size: 10,
           reductions: 455,
           garbage_collection: [
             max_heap_size: %{error_logger: true, kill: true, size: 0},
             min_bin_vheap_size: 46422,
             min_heap_size: 233,
             fullsweep_after: 65535,
             minor_gcs: 3
           ],
           suspending: []
         ],
         %{}
       )}
    ]

  defp pid(pid) when is_binary(pid) do
    pid
    |> String.to_charlist()
    |> pid()
  end

  defp pid(pid) when is_list(pid) do
    :erlang.list_to_pid(pid)
  end
end
