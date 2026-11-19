defmodule Oli.Delivery.Sections.Audited.Support do
  @moduledoc false
  # Event recording and section event proposals shared by the private modules of
  # `Oli.Delivery.Sections.Audited`.

  alias Oli.Auditing
  alias Oli.Auditing.Context
  alias Oli.Delivery.Sections.Section

  @doc "Builds the event from `proposal` and inserts it in the current transaction."
  def record(%Context{} = context, proposal) do
    with {:ok, changeset} <- Auditing.build(context, proposal),
         {:ok, _event} <- Auditing.insert(changeset) do
      :ok
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
