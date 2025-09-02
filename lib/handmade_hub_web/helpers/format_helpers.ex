defmodule HandmadeHubWeb.FormatHelpers do
  @moduledoc """
  Helper functions for formatting data in views and templates.
  """

  @doc """
  Formats a price value as currency.
  
  ## Examples
  
      iex> format_price(100)
      "100"
      
      iex> format_price(100.50)
      "101"
      
      iex> format_price(99.99)
      "100"
  """
  def format_price(price) when is_integer(price), do: to_string(price)
  
  def format_price(price) when is_float(price) do
    price
    |> round()
    |> to_string()
  end
  
  def format_price(%Decimal{} = price) do
    price
    |> Decimal.to_string()
    |> String.split(".")
    |> List.first()
  end
  
  def format_price(price) when is_binary(price) do
    case Float.parse(price) do
      {float_val, _} -> format_price(float_val)
      :error -> "0"
    end
  end
  
  def format_price(_), do: "0"
  
  @doc """
  Formats a price with currency symbol.
  
  ## Examples
  
      iex> format_currency(100)
      "K100"
      
      iex> format_currency(100.50, "USD")
      "USD101"
  """
  def format_currency(price, symbol \\ "K") do
    "#{symbol}#{format_price(price)}"
  end
end
