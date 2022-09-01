defmodule Oli.Resources.ExplanationStrategy do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :type, Ecto.Enum,
      values: [
        :after_max_resource_attempts_exhausted,
        :after_set_num_attempts
      ]

    field :set_num_attempts, :integer
  end

  @doc false
  def changeset(explanation_strategy, attrs \\ %{}) do
    explanation_strategy
    |> cast(attrs, [:type, :set_num_attempts])
    |> validate_required([:type])
  end
end
