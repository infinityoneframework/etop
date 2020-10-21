defmodule Etop.Chart do
  @moduledoc """
  Create a ascii charts.

  ## Examples

      iex> data = for i <- 1..30, do: i * 2 + :rand.uniform(4) - 2
      iex> labels = for {_, i} <- Enum.with_index(data), do: "Label \#{i}"
      iex> Etop.Chart.puts(data, labels: labels, title: "Test Plot")

                                    Test Plot
                                    ---------
      64 |                                                           *
      60 |                                                         *
      56 |                                                     * *
      52 |                                               * * *
      48 |                                             *
      44 |                                         * *
      40 |                                       *
      36 |                               * * * *
      32 |                             *
      28 |                         * *
      24 |                     * *
      20 |                 * *
      16 |             * *
      12 |       *   *
       8 |   * *   *
       4 | *
       0 |
         +-------------------+-------------------+-------------------+--
                          Label 10            Label 20
  """
  import Etop.Utils, only: [pad: 2, pad_t: 2, center: 2], warn: false

  @space 32
  @nl 10
  @empty_char @space
  @plot_char ?*

  @doc """
  Write a chart of the given data to the console.

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
      iex> Etop.Chart.puts(data, labels: label)
  """

  def generate(items, opts \\ []) do
    conf = get_config(items, opts)

    if Application.get_env(:etop, :trace) do
      IO.inspect(conf, label: "config")
    end

    scaled_items = scale_items(items, conf)
    x_count = div(Enum.count(conf.x_range) * 2, 20)

    [
      @nl,
      get_title(opts[:title], conf.title_width),
      create_main_plot(scaled_items, conf),
      create_x_axis(conf),
      create_x_labels(opts[:labels], x_count, conf.scaler_x)
    ]
  end

  @doc """
  Generate and print a chart.

  Calls generate/2 and prints the result.

  See Etop.Chart.generate/2 for more information.
  """
  def puts(items, opts \\ []) do
    items
    |> generate(opts)
    |> IO.puts()
  end

  ##############
  # Private

  defp add_config_ranges(config) do
    Map.merge(%{y_range: y_range(config.min_y, config.max_y), x_range: 0..config.len}, config)
  end

  defp create_grid(scaled_items, plot_char) do
    scaled_items
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {num, i}, acc ->
      Map.put(acc, {i, num}, plot_char)
    end)
  end

  defp create_main_plot(scaled_items, conf) do
    grid = create_grid(scaled_items, conf.plot_char)

    conf.y_range
    |> Enum.reverse()
    |> Enum.map(fn i ->
      [
        [
          pad(i * conf.scaler_y, 4),
          conf.y_label_postfix,
          @space,
          ?|,
          @space
          | Enum.map(conf.x_range, &[grid[{&1, i}] || conf.empty_char, @space])
        ],
        @nl
      ]
    end)
  end

  defp create_x_axis(conf) do
    x_axis = List.flatten(for _ <- conf.x_range, do: [?-, ?-])

    x_axis =
      x_axis
      |> Enum.chunk_every(20, 20, [])
      |> Enum.map(fn [_ | list] ->
        char = if length(list) == 19, do: ?+, else: ?-
        list ++ [char]
      end)

    [repeat(@space, String.length(conf.y_label_postfix) + 5), ?+ | x_axis]
  end

  defp create_x_labels(nil, x_count, scaler_x) do
    items = for i <- 1..x_count, do: center(to_string(i * 10 * scaler_x), 20)
    [@nl, repeat(@space, 16), items]
  end

  defp create_x_labels(labels, _, scaler_x) do
    chunk = 10 * scaler_x

    items =
      labels
      |> Enum.drop(chunk)
      |> Enum.chunk_every(chunk, chunk, [])
      |> Enum.map(fn list ->
        center(hd(list), 20)
      end)

    [@nl, repeat(@space, 16), items]
  end

  defp get_config(items, opts) do
    height = opts[:height] || 20
    width = opts[:width] || 100

    len = length(items) - 1

    max_y = items |> Enum.max() |> round()
    min_y = items |> Enum.min() |> round()

    scaler_y = if max_y <= height, do: 1, else: div(max_y - min_y + 1, height) + 1
    scaler_x = if len + 1 <= width, do: 1, else: div(len + 1, width) + 1

    scaled_len = div(len, scaler_x) + 1

    add_config_ranges(%{
      empty_char: opts[:empty_char] || @empty_char,
      height: height,
      len: scaled_len,
      max_y: div(max_y, scaler_y) + 1,
      min_y: div(min_y, scaler_y),
      orig_len: len,
      orig_max_y: max_y,
      orig_min_y: min_y,
      plot_char: opts[:plot_char] || @plot_char,
      scaler_x: scaler_x,
      scaler_y: scaler_y,
      title: opts[:title],
      title_width: scaled_len * 2,
      width: width,
      y_label_postfix: opts[:y_label_postfix] || ""
    })
  end

  defp get_title(title, width) when is_binary(title) do
    len = String.length(title)
    width = width

    leader = repeat(@space, 7)

    [
      [leader, title |> center(width), @nl],
      [leader, for(_ <- 1..len, do: ?-) |> center(width), @nl]
    ]
  end

  defp get_title(_, _), do: []

  defp repeat(char, len) do
    for _ <- 1..len, do: char
  end

  defp scale_items(items, conf) do
    leftover = for _ <- 1..conf.scaler_x, do: 0

    items
    # chunk and average the x axis
    |> Enum.chunk_every(conf.scaler_x, conf.scaler_x, leftover)
    |> Enum.map(&Enum.max/1)
    # scale the y axis
    |> Enum.map(fn i ->
      round(i / conf.scaler_y)
    end)
    |> Enum.map(&round/1)
  end

  defp y_range(min_y, max_y) do
    case Enum.to_list(min_y..max_y) do
      [0 | _] = list -> list
      list -> [0 | list]
    end
  end
end
