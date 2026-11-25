defmodule Oli.Delivery.Gating.Audited do
  @moduledoc """
  Application boundary for audited changes to the gating conditions of a section: schedule and
  always-open gates, prerequisites (started, finished, progress), and the per-student
  exceptions to either.

  Each command writes the condition, rebuilds the section's gating index when the gated
  resource changes, and records its events in one transaction under the section lock, so a
  change is never committed without its events and a failed change records nothing. Schedule
  and always-open conditions record `gating_changed`; prerequisites record
  `prerequisite_changed` with the source resource in the changes. A student exception names
  the student as the affected user. Deleting a gate deletes its student exceptions and records
  one event per deleted condition. An update that changes nothing records nothing, and the
  index rebuild records nothing of its own.

  Commands do not authorize the actor: callers keep their existing authorization. The writes
  live in private modules under this namespace, so this module is the only way to make them.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  alias Oli.Auditing.Context
  alias Oli.Delivery.Gating.Audited.Gates
  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Sections.Section

  @type command_error ::
          :invalid_request
          | :gating_condition_not_found
          | :nested_transaction
          | Ecto.Changeset.t()
          | Oli.Auditing.Error.t()
          | term()

  @doc """
  Creates a gating condition in `section` from `attrs` (the section in `attrs` is ignored) and
  records its event.
  """
  @spec create_gate(Context.t(), Section.t(), map()) ::
          {:ok, GatingCondition.t()} | {:error, command_error()}
  def create_gate(%Context{} = context, %Section{} = section, attrs) when is_map(attrs),
    do: Gates.create(context, section, attrs)

  def create_gate(_context, _section, _attrs), do: {:error, :invalid_request}

  @doc """
  Updates the gating condition `gate` of `section` with `attrs`, applied to the row read under
  the section lock, and records what changed. A gate cannot move to another section.
  """
  @spec update_gate(Context.t(), Section.t(), GatingCondition.t(), map()) ::
          {:ok, GatingCondition.t()} | {:error, command_error()}
  def update_gate(
        %Context{} = context,
        %Section{} = section,
        %GatingCondition{} = gate,
        attrs
      )
      when is_map(attrs),
      do: Gates.update(context, section, gate, attrs)

  def update_gate(_context, _section, _gate, _attrs), do: {:error, :invalid_request}

  @doc """
  Deletes the gating condition `gate` of `section` and, for a gate, its student exceptions,
  recording one event per deleted condition. Returns the deleted gate.
  """
  @spec delete_gate(Context.t(), Section.t(), GatingCondition.t()) ::
          {:ok, GatingCondition.t()} | {:error, command_error()}
  def delete_gate(%Context{} = context, %Section{} = section, %GatingCondition{} = gate),
    do: Gates.delete(context, section, gate)

  def delete_gate(_context, _section, _gate), do: {:error, :invalid_request}
end
