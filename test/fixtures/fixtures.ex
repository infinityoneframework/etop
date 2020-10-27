defmodule Etop.Fixtures do
  def proc_stat1,
    do:
      {"""
       cpu  11380053 51 3665881 1638097578 194367 213 149713 110770 0
       cpu0 2593633 25 932385 271441155 125190 213 56429 36493 0
       cpu1 4056420 3 1078261 271109295 24855 0 51832 33370 0
       cpu2 1911464 19 683974 272982292 14612 0 22177 16876 0
       cpu3 1304462 1 421962 273804241 8429 0 12846 10579 0
       cpu4 756237 0 380800 274364515 17223 0 4362 5358 0
       cpu5 757834 0 168497 274396078 4055 0 2066 8092 0
       intr 1893317733 117 7 0 0 0 0 0 0 1 0 0 1378575 104 0 0 214 0 0 0 0 0 0 0 0 0 22 0 3308291 0 1660 0 82739616 1231 0 72 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
       ctxt 2963099168
       btime 1600622981
       processes 26130033
       procs_running 1
       procs_blocked 0
       softirq 1230393695 0 445349886 52 171102841 3224872 0 2 97597213 1408845 511709984
       """,
       "9930 (beam.smp) S 24113 9930 24113 34817 9930 4202496 189946 5826 0 0 12025 1926 0 0 20 0 28 0 275236728 3164401664 42600 18446744073709551615 4194304 7475860 140732561929584 140732561927920 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0"}

  def proc_stat2,
    do:
      {"""
       cpu  11380060 51 3665883 1638099001 194367 213 149713 110770 0
       cpu0 2593637 25 932387 271441391 125190 213 56429 36493 0
       cpu1 4056420 3 1078261 271109533 24855 0 51832 33370 0
       cpu2 1911467 19 683974 272982527 14612 0 22177 16876 0
       cpu3 1304462 1 421962 273804479 8429 0 12846 10579 0
       cpu4 756237 0 380800 274364753 17223 0 4362 5358 0
       cpu5 757834 0 168497 274396316 4055 0 2066 8092 0
       intr 1893319075 117 7 0 0 0 0 0 0 1 0 0 1378577 104 0 0 214 0 0 0 0 0 0 0 0 0 22 0 3308291 0 1660 0 82739672 1231 0 72 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
       ctxt 2963101252
       btime 1600622981
       processes 26130035
       procs_running 1
       procs_blocked 0
       softirq 1230394517 0 445350180 52 171102946 3224872 0 2 97597291 1408846 511710328
       """,
       "9930 (beam.smp) S 24113 9930 24113 34817 9930 4202496 189950 5826 0 0 12027 1927 0 0 20 0 28 0 275236728 3164401664 42600 18446744073709551615 4194304 7475860 140732561929584 140732561927920 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0"}

  def proc_stats,
    do: [
      {
        {
          "cpu  11591121 66 3749421 1682036124 197096 216 150115 112640 0\n",
          "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 29339 5816 0 0 248 25 0 0 20 0 28 0 283041891 3043532800 18649 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
        },
        {
          "cpu  11591135 66 3749423 1682036710 197096 216 150115 112640 0\n",
          "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 32314 5816 0 0 261 26 0 0 20 0 28 0 283041891 3066802176 23134 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
        }
      },
      # manual2: %{sys: 1.0, total: 14.0, user: 13.0}
      {
        {
          "cpu  11591135 66 3749423 1682036710 197096 216 150115 112640 0\n",
          "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 32314 5816 0 0 261 26 0 0 20 0 28 0 283041891 3066802176 23134 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
        },
        {
          "cpu  11591149 66 3749428 1682037290 197096 216 150115 112640 0\n",
          "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 32506 5816 0 0 274 27 0 0 20 0 28 0 283041891 3065569280 22862 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
        }
      },
      # manual2: %{sys: 1.0, total: 14.0, user: 13.0}
      {
        {
          "cpu  11591149 66 3749428 1682037290 197096 216 150115 112640 0\n",
          "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 32506 5816 0 0 274 27 0 0 20 0 28 0 283041891 3065569280 22862 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
        },
        {
          "cpu  11591162 66 3749429 1682037879 197096 216 150115 112640 0\n",
          "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 32697 5816 0 0 286 28 0 0 20 0 28 0 283041891 3060473856 22497 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
        }
      },
      # manual2: %{sys: 1.0, total: 12.9, user: 11.9}
      {
        {
          "cpu  11591162 66 3749429 1682037879 197096 216 150115 112640 0\n",
          "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 32697 5816 0 0 286 28 0 0 20 0 28 0 283041891 3060473856 22497 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
        },
        {
          "cpu  11591174 66 3749430 1682038467 197096 216 150115 112640 0\n",
          "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 33126 5816 0 0 298 28 0 0 20 0 28 0 283041891 3065565184 23372 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
        }
      },
      # manual2: %{sys: 0.0, total: 12.0, user: 12.0}
      {
        {
          "cpu  11591174 66 3749430 1682038467 197096 216 150115 112640 0\n",
          "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 33126 5816 0 0 298 28 0 0 20 0 28 0 283041891 3065565184 23372 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
        },
        {
          "cpu  11591175 66 3749430 1682039067 197096 216 150115 112640 0\n",
          "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 33126 5816 0 0 299 28 0 0 20 0 28 0 283041891 3063545856 22944 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
        }
      },
      # manual2: %{sys: 0.0, total: 1.0, user: 1.0}
      {
        {
          "cpu  11591175 66 3749430 1682039067 197096 216 150115 112640 0\n",
          "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 33126 5816 0 0 299 28 0 0 20 0 28 0 283041891 3063545856 22944 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
        },
        {
          "cpu  11591176 66 3749430 1682039667 197097 216 150115 112640 0\n",
          "13871 (beam.smp) S 30901 13871 30901 34818 13871 4202496 33126 5816 0 0 299 28 0 0 20 0 28 0 283041891 3059163136 22363 18446744073709551615 4194304 7475860 140733406767344 140733406765680 256526653091 0 0 4224 134365702 18446744073709551615 0 0 17 3 0 0 0 0 0\n"
        }
      }
      # manual2: %{sys: 0.0, total: 0.0, user: 0.0}
    ]

  def procs1,
    do:
      [
        {pid('<0.0.0>'),
         [
           memory: {:memory, 26568},
           registered_name: :init,
           current_function: {:init, :boot_loop, 2},
           initial_call: {:otp_ring0, :start, 2},
           status: :waiting,
           message_queue_len: 0,
           links: [pid('<0.9.0>'), pid('<0.41.0>'), pid('<0.43.0>'), pid('<0.8.0>')],
           dictionary: [],
           trap_exit: true,
           error_handler: :error_handler,
           priority: :normal,
           group_leader: pid('<0.0.0>'),
           total_heap_size: 3196,
           heap_size: 1598,
           stack_size: 4,
           reductions: 3380,
           garbage_collection: [
             max_heap_size: %{error_logger: true, kill: true, size: 0},
             min_bin_vheap_size: 46422,
             min_heap_size: 233,
             fullsweep_after: 65535,
             minor_gcs: 2
           ],
           suspending: []
         ]},
        {pid('<0.2.0>'),
         [
           memory: {:memory, 2688},
           current_function: {:erts_literal_area_collector, :msg_loop, 4},
           initial_call: {:erts_literal_area_collector, :start, 0},
           status: :waiting,
           message_queue_len: 12,
           links: [],
           dictionary: [],
           trap_exit: true,
           error_handler: :error_handler,
           priority: :normal,
           group_leader: pid('<0.0.0>'),
           total_heap_size: 233,
           heap_size: 233,
           stack_size: 5,
           reductions: 293_121,
           garbage_collection: [
             max_heap_size: %{error_logger: true, kill: true, size: 0},
             min_bin_vheap_size: 46422,
             min_heap_size: 233,
             fullsweep_after: 65535,
             minor_gcs: 0
           ],
           suspending: []
         ]},
        {pid('<0.6.0>'),
         [
           memory: {:memory, 2688},
           current_function: {:prim_file, :helper_loop, 0},
           initial_call: {:prim_file, :start, 0},
           status: :waiting,
           message_queue_len: 12,
           links: [],
           dictionary: [],
           trap_exit: false,
           error_handler: :error_handler,
           priority: :normal,
           group_leader: pid('<0.0.0>'),
           total_heap_size: 233,
           heap_size: 233,
           stack_size: 1,
           reductions: 194,
           garbage_collection: [
             max_heap_size: %{error_logger: true, kill: true, size: 0},
             min_bin_vheap_size: 46422,
             min_heap_size: 233,
             fullsweep_after: 65535,
             minor_gcs: 0
           ],
           suspending: []
         ]},
        {pid('<0.8.0>'),
         [
           memory: {:memory, 67888},
           current_function: {Kernel.CLI, :exec_fun, 2},
           initial_call: {:erlang, :apply, 2},
           status: :waiting,
           message_queue_len: 0,
           links: [pid('<0.0.0>')],
           dictionary: [],
           trap_exit: true,
           error_handler: :error_handler,
           priority: :normal,
           group_leader: pid('<0.62.0>'),
           total_heap_size: 8370,
           heap_size: 1598,
           stack_size: 20,
           reductions: 7038,
           garbage_collection: [
             max_heap_size: %{error_logger: true, kill: true, size: 0},
             min_bin_vheap_size: 46422,
             min_heap_size: 233,
             fullsweep_after: 65535,
             minor_gcs: 7
           ],
           suspending: []
         ]}
      ]
      |> Enum.map(fn {k, v} -> {k, Enum.into(v, %{})} end)
      |> Enum.into(%{})

  def procs2,
    do:
      [
        {pid('<0.0.0>'),
         [
           memory: {:memory, 26570},
           registered_name: :init,
           current_function: {:init, :boot_loop, 2},
           initial_call: {:otp_ring0, :start, 2},
           status: :waiting,
           message_queue_len: 0,
           links: [pid('<0.9.0>'), pid('<0.41.0>'), pid('<0.43.0>'), pid('<0.8.0>')],
           dictionary: [],
           trap_exit: true,
           error_handler: :error_handler,
           priority: :normal,
           group_leader: pid('<0.0.0>'),
           total_heap_size: 3196,
           heap_size: 1598,
           stack_size: 4,
           reductions: 3388,
           garbage_collection: [
             max_heap_size: %{error_logger: true, kill: true, size: 0},
             min_bin_vheap_size: 46422,
             min_heap_size: 233,
             fullsweep_after: 65535,
             minor_gcs: 2
           ],
           suspending: []
         ]},
        {pid('<0.2.0>'),
         [
           memory: {:memory, 2688},
           current_function: {:erts_literal_area_collector, :msg_loop, 4},
           initial_call: {:erts_literal_area_collector, :start, 0},
           status: :waiting,
           message_queue_len: 5,
           links: [],
           dictionary: [],
           trap_exit: true,
           error_handler: :error_handler,
           priority: :normal,
           group_leader: pid('<0.0.0>'),
           total_heap_size: 233,
           heap_size: 233,
           stack_size: 5,
           reductions: 293_300,
           garbage_collection: [
             max_heap_size: %{error_logger: true, kill: true, size: 0},
             min_bin_vheap_size: 46422,
             min_heap_size: 233,
             fullsweep_after: 65535,
             minor_gcs: 0
           ],
           suspending: []
         ]},
        {pid('<0.6.0>'),
         [
           memory: {:memory, 2688},
           current_function: {:prim_file, :helper_loop, 0},
           initial_call: {:prim_file, :start, 0},
           status: :waiting,
           message_queue_len: 15,
           links: [],
           dictionary: [],
           trap_exit: false,
           error_handler: :error_handler,
           priority: :normal,
           group_leader: pid('<0.0.0>'),
           total_heap_size: 233,
           heap_size: 233,
           stack_size: 1,
           reductions: 500,
           garbage_collection: [
             max_heap_size: %{error_logger: true, kill: true, size: 0},
             min_bin_vheap_size: 46422,
             min_heap_size: 233,
             fullsweep_after: 65535,
             minor_gcs: 0
           ],
           suspending: []
         ]},
        {pid('<0.8.0>'),
         [
           memory: {:memory, 67888},
           current_function: {Kernel.CLI, :exec_fun, 2},
           initial_call: {:erlang, :apply, 2},
           status: :waiting,
           message_queue_len: 0,
           links: [pid('<0.0.0>')],
           dictionary: [],
           trap_exit: true,
           error_handler: :error_handler,
           priority: :normal,
           group_leader: pid('<0.62.0>'),
           total_heap_size: 8370,
           heap_size: 1598,
           stack_size: 20,
           reductions: 7038,
           garbage_collection: [
             max_heap_size: %{error_logger: true, kill: true, size: 0},
             min_bin_vheap_size: 46422,
             min_heap_size: 233,
             fullsweep_after: 65535,
             minor_gcs: 7
           ],
           suspending: []
         ]}
      ]
      |> Enum.map(fn {k, v} -> {k, Enum.into(v, %{})} end)
      |> Enum.into(%{})

  defp pid(pid), do: :erlang.list_to_pid(pid)
end
