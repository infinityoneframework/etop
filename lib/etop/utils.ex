defmodule Etop.Utils do
  @moduledoc """
  Utility helpers for Etop.
  """
  @kb 1024
  @mb @kb * @kb
  @gb @mb * @kb
  @tb @gb * @kb
  @pb @tb * @kb

  @doc """
  Center a string in the given length.

  Return a string of length >= the given length with the given string centered.

  The returned string is padded (leading and trailing) with the given padding (default " ")

  ## Examples

      iex> Etop.Utils.center("Test", 8)
      "  Test  "

      iex> Etop.Utils.center('Test', 7, "-")
      "-Test--"

      iex> Etop.Utils.center("test", 2)
      "test"
  """
  @spec center(any(), integer(), String.t()) :: String.t()
  def center(item, len, char \\ " ")

  def center(item, len, char) when is_binary(item) do
    str_len = String.length(item)

    len1 = if str_len < len, do: div(len - str_len, 2) + str_len, else: 0

    item |> pad(len1, char) |> pad_t(len, char)
  end

  def center(item, len, char), do: item |> to_string() |> center(len, char)

  @doc """
  Returns the server's local naive datetime with the microsecond field truncated to the
  given precision (:microsecond, :millisecond or :second).

  ## Arguments
    * datetime (default utc_now)
    * precision (default :second)

  ## Examples

      iex> datetime = Etop.Utils.local_time()
      iex> datetime.year >= 2020
      true

      iex> datetime = Etop.Utils.local_time(:millisecond)
      iex> elem(datetime.microsecond, 1)
      3

      iex> datetime = NaiveDateTime.utc_now()
      iex> expected = NaiveDateTime.add(datetime, Etop.Utils.timezone_offset())
      iex> Etop.Utils.local_time(datetime) == %{expected | microsecond: {0, 0}}
      true

      iex> datetime = NaiveDateTime.utc_now()
      iex> expected = NaiveDateTime.add(datetime, Etop.Utils.timezone_offset())
      iex> Etop.Utils.local_time(datetime, :microsecond) == expected
      true
  """
  @spec local_time(DateTime.t() | NaiveDateTime.t(), atom()) :: NaiveDateTime.t()
  def local_time(datetime \\ NaiveDateTime.utc_now(), precision \\ :second)

  def local_time(%NaiveDateTime{} = datetime, precision) do
    datetime
    |> NaiveDateTime.to_erl()
    |> :calendar.universal_time_to_local_time()
    |> NaiveDateTime.from_erl!()
    |> Map.put(:microsecond, datetime.microsecond)
    |> NaiveDateTime.truncate(precision)
  end

  def local_time(%DateTime{} = datetime, precision) do
    datetime
    |> DateTime.to_naive()
    |> local_time(precision)
  end

  def local_time(precision, _) when is_atom(precision) do
    local_time(NaiveDateTime.utc_now(), precision)
  end

  @doc """
  Pad (leading) the given string with spaces for the given length.

  ## Examples

      iex> Etop.Utils.pad("Test", 8)
      "    Test"

      iex> Etop.Utils.pad("Test", 2)
      "Test"

      iex> Etop.Utils.pad(100, 4, "0")
      "0100"
  """
  @spec pad(any(), integer(), String.t()) :: String.t()
  def pad(string, len, char \\ " ")
  def pad(string, len, char) when is_binary(string), do: String.pad_leading(string, len, char)
  def pad(item, len, char), do: item |> to_string() |> pad(len, char)

  @doc """
  Pad (trailing) the given string with spaces for the given length.

  ## Examples

      iex> Etop.Utils.pad_t("Test", 8)
      "Test    "

      iex> Etop.Utils.pad_t("Test", 2)
      "Test"

      iex> Etop.Utils.pad_t(10.1, 5, "0")
      "10.10"
  """
  @spec pad_t(any(), integer(), String.t()) :: String.t()
  def pad_t(string, len, char \\ " ")
  def pad_t(string, len, char) when is_binary(string), do: String.pad_trailing(string, len, char)
  def pad_t(item, len, char), do: item |> to_string() |> pad_t(len, char)

  def create_load, do: create_load(5_000_000, &(&1 * 10 + 4))

  def creat_load(count) when is_integer(count), do: create_load(count, &(&1 * 10 + 4))
  def creat_load(load) when is_function(load, 1), do: create_load(5_000_000, load)

  @doc """
  Run a short, but heavy load on the system.

  Runs a tight loop for 1 = 1..5M, i * 10 + 4.
  """
  def create_load(count, load) when is_integer(count) and is_function(load, 1) do
    Enum.each(1..5_000_000, load)
  end

  @doc """
  Runs the `run_load/0 num times, sleeping for 1 second between them.
  """
  def run_load(num \\ 10, opts \\ []) do
    log = opts[:log]
    count = opts[:count] || 5_000_000
    load = opts[:load] || (&(&1 * 10 + 4))
    sleep = Keyword.get(opts, :sleep, 1000)

    spawn(fn ->
      for i <- 1..num do
        create_load(count, load)
        if sleep, do: Process.sleep(sleep)
        if log, do: IO.puts("Done #{i} of #{num}")
      end

      if log, do: IO.puts("Done running #{num} iterations")
    end)
  end

  @doc """
  Configurable sort.

  ## Arguments

  * `list` - the enumerable to be sorted.
  * `field` (:reductions_diff) - the field to be sorted on.
  * `field_fn` (fn field -> &elem(&1, 1)[field] end) - function to get the field.
  * `sorter_fn` (&>/2) -> Sort comparator (default descending)

  ## Examples

      iex> data = [one: %{a: 3, b: 2}, two: %{a: 1, b: 3}]
      iex> Etop.Utils.sort(data, :b)
      [two: %{a: 1, b: 3}, one: %{a: 3, b: 2}]

      iex> data = [one: %{a: 3, b: 2}, two: %{a: 1, b: 3}]
      iex> Etop.Utils.sort(data, :a, sorter: &<=/2)
      [two: %{a: 1, b: 3}, one: %{a: 3, b: 2}]

      iex> data = [%{a: 1, b: 2}, %{a: 2, b: 3}]
      iex> Etop.Utils.sort(data, :a, mapper: & &1[:a])
      [%{a: 2, b: 3}, %{a: 1, b: 2}]

      iex> data = [x: %{a: 1, b: 1}, z: %{a: 2, b: 0}, y: %{a: 1, b: 2}]
      iex> Etop.Utils.sort(data, :a, secondary: :b)
      [z: %{a: 2, b: 0}, y: %{a: 1, b: 2}, x: %{a: 1, b: 1}]

      iex> data = [w: %{a: 1, b: 3}, x: %{a: 1, b: 1}, z: %{a: 2, b: 0}, y: %{a: 1, b: 2}]
      iex> data |> Etop.Utils.sort(:a, secondary: :b, mapper: &elem(&1, 1)) |> Keyword.keys()
      [:z, :w, :y, :x]
  """
  def sort(list, field, opts \\ []) do
    mapper = sort_mapper(field, opts[:mapper], opts[:secondary])
    sorter = opts[:sorter] || (&>/2)
    Enum.sort_by(list, mapper, sorter)
  end

  defp sort_mapper(field, nil, nil) do
    &elem(&1, 1)[field]
  end

  defp sort_mapper(field, nil, field) do
    sort_mapper(field, nil, nil)
  end

  defp sort_mapper(field, nil, secondary) do
    &{elem(&1, 1)[field], elem(&1, 1)[secondary]}
  end

  defp sort_mapper(_, mapper, nil) do
    mapper
  end

  defp sort_mapper(field, mapper, secondary) do
    fn x ->
      item = mapper.(x)
      {item[field], item[secondary]}
    end
  end

  @doc """
  Get the server's timezone offset in seconds.
  """
  @spec timezone_offset() :: integer
  def timezone_offset do
    NaiveDateTime.diff(NaiveDateTime.from_erl!(:calendar.local_time()), NaiveDateTime.utc_now())
  end

  @doc """
  Scale a number into xb unit with label.

  ## Examples

      iex> Etop.Utils.size_string_b(100.123)
      "100.12B"

      iex> Etop.Utils.size_string_b(10.5, 0)
      "11B"

      iex> Etop.Utils.size_string_b(1500)
      "1.46KB"
  """
  @spec size_string_b(number(), integer()) :: String.t()
  def size_string_b(size, rnd \\ 2)

  def size_string_b(size, rnd) when size < @kb,
    do: float_to_string(size, rnd) <> "B"

  def size_string_b(size, rnd),
    do: size_string_kb(size / @kb, rnd)

  @doc """
  Scale a number into xb unit with label.

  ## Examples

      iex> Etop.Utils.size_string_kb(0.253)
      "0.25KB"

      iex> Etop.Utils.size_string_kb(0.253, 1)
      "0.3KB"

      iex> Etop.Utils.size_string_kb(1500)
      "1.46MB"

      iex> Etop.Utils.size_string_kb(1024 * 1024 * 3)
      "3.0GB"

      iex> Etop.Utils.size_string_kb(1024 * 1024 * 1024 * 2.5)
      "2.5TB"

      iex> Etop.Utils.size_string_kb(1024 * 1024 * 1024 * 1024 * 1.5, 0)
      "2PB"

      iex> Etop.Utils.size_string_kb(1024 * 1024 * 1024 * 1024 * 1024, 0)
      "1EB"
  """
  @spec size_string_kb(number(), integer()) :: String.t()
  def size_string_kb(size, rnd \\ 2)

  def size_string_kb(size, rnd) when size < @kb do
    float_to_string(size, rnd) <> "KB"
  end

  def size_string_kb(size, rnd) when size < @mb do
    float_to_string(size / @kb, rnd) <> "MB"
  end

  def size_string_kb(size, rnd) when size < @gb do
    float_to_string(size / @mb, rnd) <> "GB"
  end

  def size_string_kb(size, rnd) when size < @tb do
    float_to_string(size / @gb, rnd) <> "TB"
  end

  def size_string_kb(size, rnd) when size < @pb do
    float_to_string(size / @tb, rnd) <> "PB"
  end

  def size_string_kb(size, rnd) do
    float_to_string(size / @pb, rnd) <> "EB"
  end

  @doc """
  Round a number and convert to a string.

      iex> Etop.Utils.float_to_string(1.125, 2)
      "1.13"

      iex> Etop.Utils.float_to_string(1.125, 1)
      "1.1"

      iex> Etop.Utils.float_to_string(1.5, 0)
      "2"

      iex> Etop.Utils.float_to_string(100, 0)
      "100"
  """
  @spec float_to_string(number(), integer()) :: String.t()
  def float_to_string(size, 0) when is_float(size),
    do: size |> round() |> to_string()

  def float_to_string(size, rnd) when is_float(size),
    do: size |> Float.round(rnd) |> to_string()

  def float_to_string(size, _rnd),
    do: to_string(size)
end
