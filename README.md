# Etop

[![Module Version](https://img.shields.io/hexpm/v/etop.svg)](https://hex.pm/packages/etop)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/etop/)
[![Total Download](https://img.shields.io/hexpm/dt/etop.svg)](https://hex.pm/packages/etop)
[![License](https://img.shields.io/hexpm/l/etop.svg)](https://github.com/infinityoneframework/etop/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/infinityoneframework/etop.svg)](https://github.com/infinityoneframework/etop/commits/master)

A Unix top like functionality for Elixir Applications.

## Features

* Configurable number of listed processes
* Configurable interval
* Start, Stop, Pause, and change configuration options
* Remote Node (Not working yet)
* Print results to
  * IO leader
  * text file
  * exs file
* exs file logging allow loading and post processing results
* ascii charting of results
* Monitors
  * Add 1 or monitors with configured data fields, thresholds, and callbacks

### Example output

```
===========================================================================================================================
nonode@nohost                                                                                                      08:22:56
Load:  cpu     2.9%                      Memory:  total           42812208     binary    197472
       procs     92                               processes       23093664     code    10223211
       runq       0                                atom             512625      ets      791672

Pid                        Name or Initial Func  Percent     Reds    Memory MssQ      State Current Function
---------------------------------------------------------------------------------------------------------------------------
<0.9.0>                         :erlang.apply/2    47.66   901851    284652    0    waiting :erl_prim_loader.loop/3
<0.49.0>                        :erlang.apply/2    12.57   237834    163492    0    waiting :code_server.loop/1
<0.43.0>        :application_controller.start/1     8.13   153862    264396    0    waiting :gen_server.loop/7
<0.1.0>               :erts_code_purger.start/0     7.44   140798     25848    0    waiting :erts_code_purger.wait_for_request/0
<0.2.0>     :erts_literal_area_collector.start/     7.11   134526      2688    0    waiting :erts_literal_area_collector.msg_loop/4
<0.57.0>                    :file_server.init/1     6.18   116917    426596    0    waiting :gen_server.loop/7
<0.64.0>                        :group.server/3     3.46    65443  10784016    0    waiting :group.more_data/6
<0.79.0>                       :disk_log.init/2     1.85    34950    197252    0    waiting :disk_log.loop/1
<0.228.0>                           Etop.init/1     1.77    33584   6781840    0    running Process.info/1
<0.3.0>     :erts_dirty_process_signal_handler.     1.26    23850      2688    0    waiting :erts_dirty_process_signal_handler.msg_loop/0
===========================================================================================================================
```

### Graphs

Plot CPU usage from a .exs log file.

```
iex(1)> Etop.start(file: "/tmp/etop.exs", interval: 2000)
iex(2)> Etop.load() |> Etop.Report.plot_cpu()

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
```

Plot memory usage from a .exs log file.

```
iex(1)> Etop.start(file: "/tmp/etop.exs", interval: 2000)
iex(2)> Etop.load |> Etop.Report.plot_memory(height: 15)

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
```

### Monitors

Two types of monitors are supported:

* `:summary` monitors apply to general information like `load` or `memory`.
* `:process` montitors apply to any process in the process list.

Monitor callbacks are arity 3 functions and can be specified as an function or
{module, function} tuple. The are called with the Etop state map and can
optionally return a modified version of the state. i.e. toggle reporting field.

Add a monitor to trigger when total cpu load exceeds 50%.

```elixir
iex> monitor = fn info, value, state ->
...>   IO.inspect({info, state})
...>   %{state | reporting: true}
...> end
iex> Etop.add_monitor(:summary, [:load, :total], 50.0, monitor)
```

Add a monitor to trigger when the msgq length of a process is below 10.

```elixir
iex> monitor = fn info, value, state ->
...>   IO.inspect({info, state})
...>   %{state | reporting: false}
...> end
iex> Etop.add_monitor(:process, :message_queue_len, {&</2, 10}, monitor)
iex> # or
iex> Etop.add_monitor(:process, :message_queue_len, & &1 < 10, monitor)
```

Add a monitor to trigger when memory is > 1M and < 2M bytes

```elixir
iex> Etop.add_monitor(:summary, :message_queue_len, & &1 > 1_000_000 and
...> &1 < 2_000_000, {MyMod, :callback})
```

## Why not use erlang's :etop library?

There are 2 reasons why I created this library

* Our default production installations don't have etop or observer included
* This version supports loading and post processing log files

## Installation

The package can be installed by adding `:etop` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:etop, "~> 0.7"}
  ]
end
```

## Copyright and License

`Etop` is Copyright (c) 2020-2021 E-MetroTel

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE.md](./LICENSE.md) file for more details.
