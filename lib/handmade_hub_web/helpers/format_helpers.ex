defmodule HandmadeHubWeb.FormatHelpers do
  @moduledoc """
  Helper functions for formatting data in views and templates.
  """

  @doc """
  Formats a numeric value to a money string with two decimals and thousands separators.

  Returns a string like "1,234.56" without a currency sign.
  """
  def format_price(nil), do: "0.00"
  def format_price(price) when is_integer(price), do: format_price(price * 1.0)
  def format_price(price) when is_float(price) do
    price
    |> :erlang.float_to_binary(decimals: 2)
    |> ensure_two_decimals()
    |> add_thousands()
  end
  def format_price(%Decimal{} = price) do
    price
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
    |> ensure_two_decimals()
    |> add_thousands()
  end
  def format_price(price) when is_binary(price) do
    case Decimal.cast(price) do
      {:ok, d} -> format_price(d)
      :error -> "0.00"
    end
  end
  def format_price(_), do: "0.00"

  @doc """
  Formats a price with a currency symbol (default "K").
  """
  def format_currency(price, symbol \\ "K") do
    symbol <> format_price(price)
  end

  defp ensure_two_decimals(str) do
    case String.split(str, ".") do
      [int] -> int <> ".00"
      [int, frac] when byte_size(frac) == 1 -> int <> "." <> frac <> "0"
      [int, frac] -> int <> "." <> String.slice(frac, 0, 2)
    end
  end

  defp add_thousands(str) do
    [int, frac] = String.split(str, ".")

    int_with_commas =
      int
      |> String.replace_prefix("-", "")
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map(&Enum.join/1)
      |> Enum.join(",")
      |> String.reverse()

    if String.starts_with?(int, "-") do
      "-" <> int_with_commas <> "." <> frac
    else
      int_with_commas <> "." <> frac
    end
  end
end
