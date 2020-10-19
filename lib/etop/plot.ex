defmodule Etop.Plot do
  @moduledoc """
  Text plots.
  """
  import Etop.Utils, only: [pad: 2, pad_t: 2]

  @empty_char 32

  def plot(items, opts \\ []) do
    height = opts[:height] || 20
    width = opts[:width] || 100
    label_prefix = opts[:label_prefix] || ""
    # def plot(items, height \\ 20, width \\ 100) do
    len = length(items) - 1

    # IO.inspect(Enum.map(items, &round/1), label: "items")

    max_y = items |> Enum.max() |> round()
    min_y = items |> Enum.min() |> round()

    scaler_y = if max_y <= height, do: 1, else: div(max_y - min_y + 1, height) + 1
    scaler_x = if len + 1 <= width, do: 1, else: div(len + 1, width) + 1

    orig_max_y = max_y
    orig_len = len
    orig_min_y = min_y

    max_y = div(max_y, scaler_y) + 1
    min_y = div(min_y, scaler_y)
    len = div(len, scaler_x) + 1

    leftover = for _ <- 1..scaler_x, do: 0

    scaled_items =
      items
      # chunk and average the x axis
      |> Enum.chunk_every(scaler_x, scaler_x, leftover)
      |> Enum.map(&Enum.max/1)
      # scale the y axis
      |> Enum.map(fn i ->
        round(i / scaler_y)
      end)
      |> Enum.map(&round/1)

    # |> IO.inspect(label: "scaled items")

    y_range = [0 | Enum.to_list(min_y..max_y)]
    x_range = 0..len

    # IO.inspect(%{
    #   min_y: min_y,
    #   max_y: max_y,
    #   len: len,
    #   orig_max_y: orig_max_y,
    #   orig_min_y: orig_min_y,
    #   orig_len: orig_len,
    #   width: width,
    #   height: height,
    #   scaler_x: scaler_x,
    #   scaler_y: scaler_y,
    #   x_range: x_range,
    #   y_range: y_range
    # })

    empty = for x <- x_range, y <- y_range, into: %{}, do: {{x, y}, @empty_char}

    grid =
      scaled_items
      |> Enum.with_index()
      |> Enum.reduce(empty, fn {num, i}, acc ->
        Map.put(acc, {i, num}, ?*)
      end)

    # IO.inspect(Enum.reject(grid, fn {pt, char} -> char == @empty_char end), label: "grid")

    leader = for _ <- 1..(String.length(label_prefix) + 5), do: 32
    x_axis = List.flatten(for _ <- x_range, do: [?-, ?-])
    # empty = for _ <- 1..20, do: [?-]
    x_axis =
      x_axis
      |> Enum.chunk_every(20, 20, [])
      |> Enum.map(fn [_ | list] ->
        IO.inspect(length(list), label: "len")
        char = if length(list) == 19, do: ?+, else: ?-
        list ++ [char]
      end)

    x_axis = [?+ | x_axis]

    add_leader = fn list -> list ++ leader ++ x_axis end

    x_count = div(Enum.count(x_range) * 2, 20)

    add_labels = fn list ->
      items = for i <- 1..x_count, do: pad(to_string(i * 10), 20)
      list ++ ["\n        " | items]
    end

    IO.inspect(x_count, label: "x_count")

    y_range
    |> Enum.reverse()
    |> Enum.map(fn i ->
      [
        pad(i * scaler_y, 4),
        label_prefix,
        " | " | Enum.map(x_range, &[grid[{&1, i}] || @empty_char, 32])
      ] ++
        ["\n"]
    end)
    |> add_leader.()
    |> add_labels.()
    |> IO.puts()

    # leader = for _ <- 1..(String.length(label_prefix) + 7), do: 32
    # IO.puts leader ++ x_axis
  end
end
