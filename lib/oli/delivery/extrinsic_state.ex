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
  alias Oli.Delivery.Attempts.Core, as: Attempts

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
      nil ->
        {:error, {:not_found}}

      e ->
        {:ok, filter_keys(e.state, keys)}
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
  Reads extrinsic state for a user from a resource attempt context.  Returns {:ok, map} of the keys and their
  values.

  The optional `keys` parameter is a MapSet of the string key names to retrieve. If this
  argument is not specified then all keys are returned, otherwise the return value is a map of
  key value pairs filtered to this MapSet.
  """
  def read_attempt(attempt_guid, keys \\ nil) do
    case Attempts.get_resource_attempt_by(attempt_guid: attempt_guid) do
      nil -> {:error, {:not_found}}
      attempt -> {:ok, filter_keys(attempt.state, keys)}
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
  Updates or inserts key value pairs into the extrinsic state for a user for an attempt context.
  Returns {:ok, map} of the new updated state.
  """
  def upsert_attempt(attempt_guid, key_values) do
    case Attempts.get_resource_attempt_by(attempt_guid: attempt_guid) do
      nil ->
        {:error, {:not_found}}

      attempt ->
        case Attempts.update_resource_attempt(attempt, %{
               state: Map.merge(attempt.state, key_values)
             }) do
          {:ok, u} ->
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
            notify_global(user_id, :deletion, MapSet.to_list(keys))
            {:ok, u.state}

          e ->
            e
        end
    end
  end

  @doc """
  Deletes one or more keys from the extrinsic state for a user for an attempt context. The
  keys are specified as a MapSet of string key names.

  Returns {:ok, map} of the new updated state.
  """
  def delete_attempt(attempt_guid, keys) do
    case Attempts.get_resource_attempt_by(attempt_guid: attempt_guid) do
      nil ->
        {:error, {:not_found}}

      attempt ->
        case Attempts.update_resource_attempt(attempt, %{state: delete_keys(attempt.state, keys)}) do
          {:ok, u} ->
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
            notify_section(user_id, section_slug, :deletion, MapSet.to_list(keys))
            {:ok, u.state}

          e ->
            e
        end
    end
  end

  defmodule Key do
    @moduledoc """
    Defines a key which can be used to set and retrieve extrinsic state
    """

    # TODO: implement better key management by enforcing the use of a Key struct instead of a string
    # defstruct key: nil

    # def alternatives_preference(alternatives_id), do: %__MODULE__{key: "alt_pref_#{alternatives_id}"}

    @doc """
    Returns the key for alternatives preference state
    """
    def alternatives_preference(alternatives_id), do: "alt_pref_#{alternatives_id}"

    @doc """
    Returns the key for checking if the user has visited a section
    """
    def has_visited_once(), do: "has_visited_once"
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
      "user_global_state:" <> Integer.to_string(user_id),
      {action, payload}
    )
  end

  defp notify_section(user_id, section_slug, action, payload) do
    PubSub.broadcast(
      Oli.PubSub,
      "user_section_state:" <> section_slug <> ":" <> Integer.to_string(user_id),
      {action, payload}
    )
  end
end
