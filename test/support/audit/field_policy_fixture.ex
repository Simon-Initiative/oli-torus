defmodule Oli.Auditing.FieldPolicyFixture do
  @moduledoc """
  Schema used by `Oli.Auditing.FieldPolicyDriftTest` to prove that the drift checks detect a
  new column, a redacted column audited as a value, and stale policy entries.
  """

  use Ecto.Schema

  embedded_schema do
    field :max_attempts, :integer
    field :extra_time_multiplier, :float
    field :webhook_secret, :string, redact: true
  end
end
