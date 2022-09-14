defmodule Oli.Resources.ExplanationStrategy do
  use Ecto.Schema
  import Ecto.Changeset

  def types() do
    [
      :none,
      :after_max_resource_attempts_exhausted,
      :after_set_num_attempts
    ]
  end

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
  def changeset(explanation_strategy, attrs \\ %{})

  def changeset(explanation_strategy, %Oli.Resources.ExplanationStrategy{} = attrs) do
    # if attrs is given as a struct, then convert it to a map in order to process
    changeset(explanation_strategy, Map.from_struct(attrs))
  end

  def changeset(explanation_strategy, attrs) do
    explanation_strategy
    |> cast(attrs, [:type, :set_num_attempts])
    |> validate_required([:type])
  end
end
