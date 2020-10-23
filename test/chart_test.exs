defmodule Etop.ChartTest do
  use ExUnit.Case

  alias Etop.Chart

  # test "generate/2" do
  #   Chart.puts(data(), title: "Test Chart")
  # end

  # test "generate/2 with labels" do
  #   data = data()
  #   labels = for {_, i} <- Enum.with_index(data), do: "Label #{i}"

  #   chart =
  #     data
  #     |> Chart.generate(title: "Test Chart", labels: labels)
  #     |> List.flatten()
  #     |> Enum.chunk_by(fn x -> x == 10 end)

  #   IO.inspect(chart, label: "Chart", limit: :infinity, pretty: true)

  #   IO.puts(chart)
  # end

  test "title spacing no scaling" do
    data = data()
    labels = for {_, i} <- Enum.with_index(data), do: "Label #{i}"

    [_, t1, _, t2 | _] =
      data
      |> Chart.generate(title: "Test Chart", labels: labels)
      |> List.flatten()
      |> Enum.chunk_by(fn x -> x == 10 end)

    # IO.puts(chart)

    title = List.last(t1)
    assert String.length(title) == 134
    assert List.last(t2) |> String.length() == 134
    assert String.length(String.trim_trailing(title)) - div(String.length("Test Chart"), 2) == 67
  end

  test "title spacing with scaling" do
    data = data()
    labels = for {_, i} <- Enum.with_index(data), do: "Label #{i}"

    # chart =
    [_, t1, _, t2 | _] =
      data
      |> Chart.generate(title: "Test Chart", labels: labels, width: 50)
      |> List.flatten()
      |> Enum.chunk_by(fn x -> x == 10 end)

    # IO.puts(chart)

    title = List.last(t1)
    assert String.length(title) == 80
    assert List.last(t2) |> String.length() == 80
    assert String.length(String.trim_trailing(title)) - div(String.length("Test Chart"), 2) == 40
  end

  # defp data(lower, len),
  #   do: Enum.slice(data(), lower, len)

  defp data,
    do: [
      2,
      3,
      10,
      15,
      15,
      22,
      26,
      27,
      30,
      35,
      38,
      43,
      47,
      51,
      56,
      62,
      62,
      66,
      71,
      76,
      80,
      83,
      91,
      93,
      99,
      100,
      104,
      108,
      112,
      119,
      120,
      126,
      128,
      135,
      134,
      140,
      146,
      151,
      153,
      159,
      161,
      162,
      166,
      172,
      174,
      182,
      186,
      188,
      191,
      197,
      199,
      203,
      207,
      213,
      214,
      219,
      224,
      227,
      231,
      239,
      242,
      244,
      251,
      255,
      259,
      262,
      262,
      269,
      275,
      274,
      278,
      287,
      287,
      292,
      296,
      303,
      306,
      308,
      315,
      316,
      320,
      325,
      331,
      335,
      336,
      340,
      346,
      347,
      354,
      354,
      360,
      367,
      371,
      375,
      376,
      378,
      386,
      391,
      395,
      399,
      401,
      403,
      408,
      413,
      414,
      421,
      423,
      430,
      433,
      436,
      441,
      446,
      450,
      451,
      458,
      461,
      466,
      467,
      471,
      476,
      478,
      485,
      487,
      493,
      497,
      500,
      502,
      510,
      512,
      518,
      522,
      527,
      531,
      530,
      535,
      540,
      546,
      550,
      551,
      555,
      559,
      564,
      567,
      574,
      575,
      580,
      583,
      586,
      594,
      598,
      600,
      607,
      607,
      610,
      615,
      623,
      624,
      627,
      633,
      635,
      640,
      643,
      649,
      653,
      654,
      659,
      664,
      667,
      670,
      677,
      679,
      687,
      687,
      694,
      695,
      699,
      702,
      707,
      715,
      717,
      721,
      722,
      729,
      735,
      734,
      741,
      747,
      747,
      752,
      758,
      763,
      765,
      767,
      771,
      778,
      779,
      784,
      791,
      792,
      796
    ]
end

# +-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+----------------
#                     30                  60                  90                 120                 150                 180
# "                                             Test Chart                                             "],
