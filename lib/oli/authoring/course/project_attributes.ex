defmodule Oli.Authoring.Course.ProjectAttributes do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    # For language-learning projects, what language are we targeting?
    field :learning_language, :string
    embeds_one :license, ProjectAttributes.License
    field :calculate_embeddings_on_publish, :boolean, default: false
    field :coverage_formative_threshold, :integer, default: 3
    field :coverage_summative_threshold, :integer, default: 3
  end

  @type module_struct_or_changeset_type :: %ProjectAttributes{} | %Ecto.Changeset{}
  @spec changeset(module_struct_or_changeset_type, map) :: %Ecto.Changeset{}
  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :learning_language,
      :calculate_embeddings_on_publish,
      :coverage_formative_threshold,
      :coverage_summative_threshold
    ])
    |> validate_number(:coverage_formative_threshold, greater_than_or_equal_to: 0)
    |> validate_number(:coverage_summative_threshold, greater_than_or_equal_to: 0)
    |> cast_embed(:license, required: false)
  end

  @doc """
  Returns a project's coverage thresholds as `%{formative: _, summative: _}`,
  read from its persisted `attributes`. Projects predating this field (or any
  project whose `attributes` embed is absent) read as `3`/`3` — the same
  recommended default persisted on new projects by this schema, kept as an
  independent literal here rather than depending on
  `Oli.Authoring.ObjectiveCoverage.Issues.default_thresholds/0` so this
  low-level schema module has no dependency on that domain-classification
  module.
  """
  @spec coverage_thresholds(module_struct_or_changeset_type() | nil) :: %{
          formative: non_neg_integer(),
          summative: non_neg_integer()
        }
  def coverage_thresholds(nil), do: %{formative: 3, summative: 3}

  def coverage_thresholds(%ProjectAttributes{} = attributes) do
    %{
      formative: attributes.coverage_formative_threshold,
      summative: attributes.coverage_summative_threshold
    }
  end
end

defmodule Oli.Authoring.Course.ProjectAttributes.License do
  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Authoring.Course.CreativeCommons
  alias __MODULE__

  @license_opts Map.keys(CreativeCommons.cc_options())

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field(:license_type, Ecto.Enum, values: @license_opts, default: :none)
    field(:custom_license_details, :string, default: "")
  end

  @type module_struct_or_changeset_type :: %License{} | %Ecto.Changeset{}
  @spec changeset(module_struct_or_changeset_type, map) :: %Ecto.Changeset{}
  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [:license_type, :custom_license_details])
  end
end
