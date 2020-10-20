defmodule Etop.Utils do
  @doc """
  Returns the server's local naive datetime with the microsecond field truncated to the
  given precision (:microsecond, :millisecond or :second).

  ## Arguments
    * datetime (default utc_now)
    * precision (default :second)

  ## Examples

      iex> datetime = InfinityOne.Utils.local_time()
      iex> datetime.year >= 2020
      true

      iex> datetime = InfinityOne.Utils.local_time(:millisecond)
      iex> elem(datetime.microsecond, 1)
      3

      iex> datetime = NaiveDateTime.utc_now()
      iex> expected = NaiveDateTime.add(datetime, InfinityOne.Utils.timezone_offset())
      iex> InfinityOne.Utils.local_time(datetime) == %{expected | microsecond: {0, 0}}
      true

      iex> datetime = NaiveDateTime.utc_now()
      iex> expected = NaiveDateTime.add(datetime, InfinityOne.Utils.timezone_offset())
      iex> InfinityOne.Utils.local_time(datetime, :microsecond) == expected
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

  def pad(string, len) when is_binary(string), do: String.pad_leading(string, len, " ")
  def pad(item, len), do: item |> to_string() |> pad(len)

  def pad_t(string, len) when is_binary(string), do: String.pad_trailing(string, len, " ")
  def pad_t(item, len), do: item |> to_string() |> pad_t(len)

  def center(item, len) when is_binary(item) do
    str_len = String.length(item)

    len1 = if str_len < len, do: div(len - str_len, 2) + str_len, else: 0

    item |> pad(len1) |> pad_t(len)
  end

  def center(item, len), do: item |> to_string() |> center(len)
end
