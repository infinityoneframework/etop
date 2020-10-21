# Etop - A Unix like top library for Elixir Applications

[license-img]: http://img.shields.io/badge/license-MIT-brightgreen.svg
[license]: http://opensource.org/licenses/MIT

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

## Why not use erlang's :etop library?

There are 2 reasons why I created this library

* Our default production installations don't have etop or observer included
* This version supports loading and post processing log files

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `etop` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:etop, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/etop](https://hexdocs.pm/etop).

## License

`Etop` is Copyright (c) 2020-2021 E-MetroTel

The source code is released under the MIT License.

Check [LICENSE](LICENSE.md) for more information.
