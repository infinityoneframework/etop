defmodule Etop.ReportTest do
  use ExUnit.Case, async: true

  alias Etop.Report

  setup do
    {:ok, data: data1()}
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
               percent: "37.83%",
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
               percent: "50.44%",
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
