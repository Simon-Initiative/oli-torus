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
  Returns a project's persisted coverage thresholds, using the recommended
  `3`/`3` defaults when the attributes embed is absent.
  """
  @spec coverage_thresholds(%ProjectAttributes{} | nil) :: %{
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
