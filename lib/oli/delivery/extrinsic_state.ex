defmodule Oli.Delivery.ExtrinsicState do
  import Ecto.Query, warn: false

  alias Oli.Accounts

  def read_section(user_id, section_slug, keys \\ nil) do
    {:ok, %{}}
  end

  def read_global(user_id, keys \\ nil) do
    case Accounts.get_user_by(sub: user_id) do
      nil -> {:error, {:not_found}}
      user -> {:ok, filter_keys(user.state, keys)}
    end
  end

  def upsert_section(user_id, section_slug, key_values) do
    {:ok, %{}}
  end

  def upsert_global(user_id, key_values) do
    case Accounts.get_user_by(sub: user_id) do
      nil ->
        {:error, {:not_found}}

      user ->
        case Accounts.update_user(user, %{state: Map.merge(user.state, key_values)}) do
          {:ok, u} -> {:ok, u.state}
          e -> e
        end
    end
  end

  def delete_global(user_id, keys) do
    case Accounts.get_user_by(sub: user_id) do
      nil ->
        {:error, {:not_found}}

      user ->
        case Accounts.update_user(user, %{state: delete_keys(user.state, keys)}) do
          {:ok, u} -> {:ok, u.state}
          e -> e
        end
    end
  end

  def delete_section(_user_id, _keys, _section_slug) do
    {:ok, %{}}
  end

  defp filter_keys(state, nil), do: state

  defp filter_keys(state, keys) do
    Map.keys(state)
    |> Enum.reduce(%{}, fn k, m ->
      if MapSet.member?(keys, k) do
        Map.put(m, k, Map.get(state, k))
      else
        m
      end
    end)
  end

  defp delete_keys(state, keys) do
    Map.keys(state)
    |> Enum.reduce(%{}, fn k, m ->
      if MapSet.member?(keys, k) do
        m
      else
        Map.put(m, k, Map.get(state, k))
      end
    end)
  end
end
