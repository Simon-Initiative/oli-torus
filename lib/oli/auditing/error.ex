defmodule Oli.Auditing.Error do
  @moduledoc """
  Safe description of a failed audit write.

  It carries a stable code, the event type, and a correlation ID that also appears in the log
  line for the failure. It never carries the rejected values or the changeset.

  Codes:
    * `:invalid_event` - the row does not satisfy the envelope or its event contract
    * `:no_changes` - a `:skip` event with nothing to record
    * `:partition_missing` - no partition covers the row's `inserted_at`, or one could not be
      provisioned
    * `:insert_failed` - any other database failure
  """

  @enforce_keys [:code, :correlation_id]
  defstruct [:code, :event_type, :correlation_id]

  @type code :: :invalid_event | :no_changes | :partition_missing | :insert_failed

  @type t :: %__MODULE__{
          code: code(),
          event_type: atom() | nil,
          correlation_id: Ecto.UUID.t()
        }

  @doc "Builds an error with a new correlation ID."
  @spec new(code(), atom() | nil) :: t()
  def new(code, event_type \\ nil),
    do: %__MODULE__{code: code, event_type: event_type, correlation_id: Ecto.UUID.generate()}
end
