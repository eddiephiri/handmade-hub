defmodule HandmadeHub.Settings do
  @moduledoc """
  Manages platform-wide settings.
  """
  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Settings.Setting

  def get(key, default \\ nil) when is_binary(key) do
    case Repo.get_by(Setting, key: key) do
      %Setting{value: value, data_type: type} -> cast_value(value, type)
      _ -> default
    end
  end

  def put(key, value, data_type \\ "string") when is_binary(key) do
    str_val = encode_value(value, data_type)
    case Repo.get_by(Setting, key: key) do
      nil -> %Setting{} |> Setting.changeset(%{key: key, value: str_val, data_type: data_type}) |> Repo.insert()
      %Setting{} = s -> s |> Setting.changeset(%{value: str_val, data_type: data_type}) |> Repo.update()
    end
  end

  defp encode_value(value, "json"), do: Jason.encode!(value)
  defp encode_value(value, "boolean") when is_boolean(value), do: if(value, do: "true", else: "false")
  defp encode_value(value, "integer") when is_integer(value), do: Integer.to_string(value)
  defp encode_value(value, _), do: to_string(value)

  defp cast_value(nil, _), do: nil
  defp cast_value(value, "json"), do: Jason.decode!(value)
  defp cast_value(value, "boolean"), do: value == "true"
  defp cast_value(value, "integer"), do: String.to_integer(value)
  defp cast_value(value, _), do: value
end
