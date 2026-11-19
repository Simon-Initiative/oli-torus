defmodule Oli.Delivery.Sections.Audited.Support do
  @moduledoc false
  # Event recording and section event proposals shared by the private modules of
  # `Oli.Delivery.Sections.Audited`.

  import Ecto.Query, only: [from: 2]

  alias Oli.Auditing
  alias Oli.Auditing.Context
  alias Oli.Delivery.Sections.{Section, SectionResource}
  alias Oli.Repo

  @doc "Builds the event from `proposal` and inserts it in the current transaction."
  def record(%Context{} = context, proposal) do
    with {:ok, changeset} <- Auditing.build(context, proposal),
         {:ok, _event} <- Auditing.insert(changeset) do
      :ok
    end
  end

  @doc """
  Builds an event from each of `proposals` and inserts them in one statement in the current
  transaction. Proposals of events that record nothing without changes (`no_op: :skip`) and
  have none are left out.
  """
  def record_many(%Context{} = context, proposals) do
    proposals
    |> Enum.reduce_while({:ok, []}, fn proposal, {:ok, changesets} ->
      case Auditing.build(context, proposal) do
        {:ok, changeset} -> {:cont, {:ok, [changeset | changesets]}}
        {:error, :no_changes} -> {:cont, {:ok, changesets}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, changesets} -> changesets |> Enum.reverse() |> Auditing.insert_all()
      error -> error
    end
  end

  @doc """
  Locks the row of the section with `id` (`FOR NO KEY UPDATE`) and returns it, so that it is
  the before-state of the write that follows in the same transaction.
  """
  def lock_section(id) do
    case Repo.one(from(s in Section, where: s.id == ^id, lock: "FOR NO KEY UPDATE")) do
      nil -> {:error, :not_found}
      section -> {:ok, section}
    end
  end

  @doc """
  Carries onto `updated` the associations that were loaded on `given`, the section the caller
  passed, so commands return the section in the shape the caller had it (including nested
  preloads). A `belongs_to` association whose foreign key the write changed is read again.
  """
  def preload_like(%Section{} = updated, %Section{} = given) do
    Enum.reduce(Section.__schema__(:associations), updated, fn association, acc ->
      case Map.get(given, association) do
        %Ecto.Association.NotLoaded{} -> acc
        value -> carry_association(acc, given, association, value)
      end
    end)
  end

  defp carry_association(updated, given, association, value) do
    case Section.__schema__(:association, association) do
      %Ecto.Association.BelongsTo{owner_key: key} when is_map_key(updated, key) ->
        case Map.get(updated, key) == Map.get(given, key) do
          true -> Map.put(updated, association, value)
          false -> Repo.preload(updated, association, force: true)
        end

      _reflection ->
        Map.put(updated, association, value)
    end
  end

  @doc "Locks and returns the section resource of `section_id` for `resource_id`."
  def lock_section_resource(section_id, resource_id) do
    from(sr in SectionResource,
      where: sr.section_id == ^section_id and sr.resource_id == ^resource_id,
      lock: "FOR NO KEY UPDATE"
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      section_resource -> {:ok, section_resource}
    end
  end

  @doc """
  The entity kind of `section`'s lifecycle events: `:product` for sections of type
  `:blueprint` (course section templates), `:section` otherwise.
  """
  def kind(%Section{type: :blueprint}), do: :product
  def kind(%Section{}), do: :section

  @doc """
  A lifecycle event proposal for `section`: `verb` is `:created`, `:deleted`, `:archived`, or
  `:settings_changed`, and the event is `<kind>_<verb>`.
  """
  def lifecycle_proposal(%Section{id: id} = section, verb, attrs \\ %{}) do
    kind = kind(section)

    Map.merge(
      %{
        event_type: :"#{kind}_#{verb}",
        entity: {kind, id, section},
        scope: scope(section),
        event_key: "#{kind}:#{id}:#{verb}"
      },
      attrs
    )
  end

  @doc "The scope columns of an event about `section`."
  def scope(%Section{} = section) do
    %{
      section_id: section.id,
      project_id: section.base_project_id,
      institution_id: section.institution_id
    }
    |> Map.reject(fn {_column, value} -> not is_integer(value) end)
  end
end
