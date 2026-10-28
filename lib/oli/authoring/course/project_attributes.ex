defmodule Oli.Authoring.Course.ProjectAttributes do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  @default_coverage_threshold 3
  @coverage_threshold_fields [
    :coverage_formative_threshold,
    :coverage_summative_threshold
  ]

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    # For language-learning projects, what language are we targeting?
    field :learning_language, :string
    embeds_one :license, ProjectAttributes.License
    field :calculate_embeddings_on_publish, :boolean, default: false
    field :coverage_formative_threshold, :integer, default: @default_coverage_threshold
    field :coverage_summative_threshold, :integer, default: @default_coverage_threshold
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
    |> validate_required(@coverage_threshold_fields)
    |> validate_number(:coverage_formative_threshold, greater_than_or_equal_to: 0)
    |> validate_number(:coverage_summative_threshold, greater_than_or_equal_to: 0)
    |> cast_embed(:license, required: false)
  end

  @doc """
  Returns a project's persisted coverage thresholds, using the recommended
  `3`/`3` defaults when the attributes embed is absent.
  """
  @spec coverage_thresholds(%ProjectAttributes{} | nil) :: %{
          formative: non_neg_integer(),
          summative: non_neg_integer()
        }
  def coverage_thresholds(nil) do
    %{formative: @default_coverage_threshold, summative: @default_coverage_threshold}
  end

  def coverage_thresholds(%ProjectAttributes{} = attributes) do
    %{
      formative: attributes.coverage_formative_threshold || @default_coverage_threshold,
      summative: attributes.coverage_summative_threshold || @default_coverage_threshold
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
