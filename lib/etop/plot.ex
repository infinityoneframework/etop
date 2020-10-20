defmodule Etop.Plot do
  @moduledoc """
  Text plots.
  """
  import Etop.Utils, only: [pad: 2, pad_t: 2, center: 2], warn: false

  @empty_char 32
  @plot_char ?*

  @doc """
  Write a plot of the given data to the console.

  Creates a plot of some time scale data with the following features:

  * plot title
  * configurable chart height and width
  * performs y axis down scaling to fit to the given width
  * performs x axis down-scaling by taking the max of values in the scaling group
  * Performs y axis lower bound truncating (0, min..max)
  * x scale label prefix
  * option x axis labels (defaults to the series number if not provided)

  ## Options

  * height (20) - the height of the y axis
  * width (100) - the width of the x axis
  * y_label_postfix ("") - the appended y axis label
  * title (nil) - Sting printed at the top of the chart
  * labels (nil) - List of x-axis labels
  * empty_char (0x20 - space) - the character for an empty char
  * plot_char (?*) - the character for a plot point

  ## Examples

      iex> data = Enum.to_list(1..20)
      iex> labels = for i <- data, do: "Label \#{i}"
      iex> Etop.Plot(data, labels: label)
  """
  def plot(items, opts \\ []) do
    height = opts[:height] || 20
    width = opts[:width] || 100
    y_label_postfix = opts[:y_label_postfix] || ""
    empty_char = opts[:empty_char] || @empty_char
    plot_char = opts[:plot_char] || @plot_char

    len = length(items) - 1

    title_width = if len * 2 < width, do: len * 2, else: width

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

    title_width = if len < width, do: len, else: width

    IO.inspect({title_width, len, width}, label: "title_width, len, width")

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

    y_range = Enum.to_list(min_y..max_y)

    y_range =
      case y_range do
        [0 | _] -> y_range
        list -> [0 | list]
      end

    x_range = 0..len

    if Application.get_env(:etop, :trace) do
      IO.inspect(%{
        min_y: min_y,
        max_y: max_y,
        len: len,
        orig_max_y: orig_max_y,
        orig_min_y: orig_min_y,
        orig_len: orig_len,
        width: width,
        height: height,
        scaler_x: scaler_x,
        scaler_y: scaler_y,
        x_range: x_range,
        y_range: y_range
      })
    end

    grid = create_grid(scaled_items, plot_char)

    leader = for _ <- 1..(String.length(y_label_postfix) + 5), do: 32

    x_axis = create_x_axis(x_range)

    add_leader = fn list -> list ++ leader ++ x_axis end

    x_count = div(Enum.count(x_range) * 2, 20)

    print_title(opts[:title], title_width)

    y_range
    |> Enum.reverse()
    |> Enum.map(fn i ->
      [
        pad(i * scaler_y, 4),
        y_label_postfix,
        " | " | Enum.map(x_range, &[grid[{&1, i}] || empty_char, 32])
      ] ++
        ["\n"]
    end)
    |> add_leader.()
    |> add_x_labels(opts[:labels], x_count, scaler_x)
    |> IO.puts()
  end

  defp add_x_labels(list, nil, x_count, scaler_x) do
    items = for i <- 1..x_count, do: center(to_string(i * 10 * scaler_x), 20)
    list ++ ["\n                " | items]
  end

  defp add_x_labels(list, labels, _, scaler_x) do
    chunk = 10 * scaler_x

    items =
      labels
      |> Enum.drop(chunk)
      |> Enum.chunk_every(chunk, chunk, [])
      |> Enum.map(fn list ->
        center(hd(list), 20)
      end)

    list ++ ["\n                " | items]
  end

  defp create_grid(scaled_items, plot_char) do
    scaled_items
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {num, i}, acc ->
      Map.put(acc, {i, num}, plot_char)
    end)
  end

  defp create_x_axis(x_range) do
    x_axis = List.flatten(for _ <- x_range, do: [?-, ?-])

    x_axis =
      x_axis
      |> Enum.chunk_every(20, 20, [])
      |> Enum.map(fn [_ | list] ->
        char = if length(list) == 19, do: ?+, else: ?-
        list ++ [char]
      end)

    [?+ | x_axis]
  end

  defp print_title(title, width) when is_binary(title) do
    len = String.length(title)
    width = width * 2

    leader = for _ <- 1..7, do: 32

    IO.puts([
      leader,
      title |> center(width),
      10,
      leader,
      for(_ <- 1..len, do: ?-) |> center(width)
    ])
  end

  defp print_title(_, _), do: :ok
end
