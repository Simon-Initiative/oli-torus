defmodule Oli.Delivery.ExtrinsicState do
  @moduledoc """
  Enables arbitrary key-value pair storage that is extrinsic to any specific activity attempt.

  Extrinsic state exists either truly global for a user, or scoped to a course section for
  a user. Leveraging this, activities can be built that share state across pages in a course, and
  across courses.

  The fundamental operations on extrinsic state are read, upsert, and deletion.  Each operation
  works on a collection of keys (or key value pairs).
  """

  import Ecto.Query, warn: false

  alias Oli.Accounts
  alias Oli.Delivery.Sections

  alias Phoenix.PubSub

  @doc """
  Reads extrinsic state for a user for a specific section.  Returns {:ok, map} of the keys and their
  values.

  The optional `keys` parameter is a MapSet of the string key names to retrieve. If this
  argument is not specified then all keys are returned, otherwise the return value is a map of
  key value pairs filtered to this MapSet.
  """
  def read_section(user_id, section_slug, keys \\ nil) do
    case Sections.get_enrollment(section_slug, user_id) do
      nil -> {:error, {:not_found}}
      e -> {:ok, filter_keys(e.state, keys)}
    end
  end

  @doc """
  Reads extrinsic state for a user from the global context.  Returns {:ok, map} of the keys and their
  values.

  The optional `keys` parameter is a MapSet of the string key names to retrieve. If this
  argument is not specified then all keys are returned, otherwise the return value is a map of
  key value pairs filtered to this MapSet.
  """
  def read_global(user_id, keys \\ nil) do
    case Accounts.get_user_by(id: user_id) do
      nil -> {:error, {:not_found}}
      user -> {:ok, filter_keys(user.state, keys)}
    end
  end

  @doc """
  Updates or inserts key value pairs into the extrinsic state for a user for a particular section.
  Returns {:ok, map} of the new updated state.
  """
  def upsert_section(user_id, section_slug, key_values) do
    case Sections.get_enrollment(section_slug, user_id) do
      nil ->
        {:error, {:not_found}}

      e ->
        case Sections.update_enrollment(e, %{state: Map.merge(e.state, key_values)}) do
          {:ok, u} ->
            notify_section(user_id, section_slug, :delta, key_values)
            {:ok, u.state}

          e ->
            e
        end
    end
  end

  @doc """
  Updates or inserts key value pairs into the extrinsic state for a user for the global context.
  Returns {:ok, map} of the new updated state.
  """
  def upsert_global(user_id, key_values) do
    case Accounts.get_user_by(id: user_id) do
      nil ->
        {:error, {:not_found}}

      user ->
        case Accounts.update_user(user, %{state: Map.merge(user.state, key_values)}) do
          {:ok, u} ->
            notify_global(user_id, :delta, key_values)
            {:ok, u.state}

          e ->
            e
        end
    end
  end

  @doc """
  Deletes one or more keys from the extrinsic state for a user for the global context. The
  keys are specified as a MapSet of string key names.

  Returns {:ok, map} of the new updated state.
  """
  def delete_global(user_id, keys) do
    case Accounts.get_user_by(id: user_id) do
      nil ->
        {:error, {:not_found}}

      user ->
        case Accounts.update_user(user, %{state: delete_keys(user.state, keys)}) do
          {:ok, u} ->
            notify_global(user_id, :deletion, keys)
            {:ok, u.state}

          e ->
            e
        end
    end
  end

  @doc """
  Deletes one or more keys from the extrinsic state for a user for a particular section. The
  keys are specified as a MapSet of string key names.

  Returns {:ok, map} of the new updated state.
  """
  def delete_section(user_id, section_slug, keys) do
    case Sections.get_enrollment(section_slug, user_id) do
      nil ->
        {:error, {:not_found}}

      e ->
        case Sections.update_enrollment(e, %{state: delete_keys(e.state, keys)}) do
          {:ok, u} ->
            notify_section(user_id, section_slug, :deletion, keys)
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

  defp notify_global(user_id, action, payload) do
    PubSub.broadcast(
      Oli.PubSub,
      "global:" <> Integer.to_string(user_id),
      {action, payload}
    )
  end

  defp notify_section(user_id, section_slug, action, payload) do
    PubSub.broadcast(
      Oli.PubSub,
      "section:" <> section_slug <> ":" <> Integer.to_string(user_id),
      {action, payload}
    )
  end
end
