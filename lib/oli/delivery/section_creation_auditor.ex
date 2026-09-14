defmodule Oli.Delivery.SectionCreationAuditor do
  @moduledoc """
  Audit sink for course section creation.

  Section creation is rolled back when its audit record cannot be written, so the sink is
  resolved through application configuration: the failure path is reachable in tests
  without a caller being able to choose it.
  """

  @callback capture(
              actor :: struct() | nil,
              event_type :: atom(),
              resource :: struct() | nil,
              details :: map()
            ) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}

  def capture(actor, event_type, resource, details),
    do: impl().capture(actor, event_type, resource, details)

  defp impl(), do: Application.get_env(:oli, :section_creation_auditor, Oli.Auditing)
end
