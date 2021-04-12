defmodule Oli.Delivery.ExtrinsicState do
  import Ecto.Query, warn: false

  alias Oli.Accounts
  alias Oli.Delivery.Sections

  alias Phoenix.PubSub

  def read_section(user_sub, section_slug, keys \\ nil) do
    case Sections.get_enrollment(section_slug, user_sub) do
      nil -> {:error, {:not_found}}
      e -> {:ok, filter_keys(e.state, keys)}
    end
  end

  def read_global(user_sub, keys \\ nil) do
    case Accounts.get_user_by(sub: user_sub) do
      nil -> {:error, {:not_found}}
      user -> {:ok, filter_keys(user.state, keys)}
    end
  end

  def upsert_section(user_sub, section_slug, key_values) do
    case Sections.get_enrollment(section_slug, user_sub) do
      nil ->
        {:error, {:not_found}}

      e ->
        case Sections.update_enrollment(e, %{state: Map.merge(e.state, key_values)}) do
          {:ok, u} ->
            notify_section(user_sub, section_slug, :delta, key_values)
            {:ok, u.state}

          e ->
            e
        end
    end
  end

  def upsert_global(user_sub, key_values) do
    case Accounts.get_user_by(sub: user_sub) do
      nil ->
        {:error, {:not_found}}

      user ->
        case Accounts.update_user(user, %{state: Map.merge(user.state, key_values)}) do
          {:ok, u} ->
            notify_global(user_sub, :delta, key_values)
            {:ok, u.state}

          e ->
            e
        end
    end
  end

  def delete_global(user_sub, keys) do
    case Accounts.get_user_by(sub: user_sub) do
      nil ->
        {:error, {:not_found}}

      user ->
        case Accounts.update_user(user, %{state: delete_keys(user.state, keys)}) do
          {:ok, u} ->
            notify_global(user_sub, :deletion, keys)
            {:ok, u.state}

          e ->
            e
        end
    end
  end

  def delete_section(user_sub, section_slug, keys) do
    case Sections.get_enrollment(section_slug, user_sub) do
      nil ->
        {:error, {:not_found}}

      e ->
        case Sections.update_enrollment(e, %{state: delete_keys(user.state, keys)}) do
          {:ok, u} ->
            notify_section(user_sub, section_slug, :delta, key_values)
            {:ok, u.state}

          e ->
            e
        end
    end
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

  defp notify_global(user_sub, action, payload) do
    PubSub.broadcast(
      Oli.PubSub,
      "global:" <> user_sub,
      {action, payload}
    )
  end

  defp notify_section(user_sub, section_slug, action, payload) do
    PubSub.broadcast(
      Oli.PubSub,
      "section:" <> section_slug <> ":" <> user_sub,
      {action, payload}
    )
  end
end
