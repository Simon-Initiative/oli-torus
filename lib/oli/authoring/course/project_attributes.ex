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
  end

  @type module_struct_or_changeset_type :: %ProjectAttributes{} | %Ecto.Changeset{}
  @spec changeset(module_struct_or_changeset_type, map) :: %Ecto.Changeset{}
  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [:learning_language])
    |> cast_embed(:license, required: false)
  end
end

defmodule Oli.Authoring.Course.ProjectAttributes.License do
  use Ecto.Schema
  import Ecto.Changeset
  import Oli.Utils
  alias Oli.Authoring.Course.CreativeCommons
  alias __MODULE__

  @license_opts Map.keys(CreativeCommons.cc_options())

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
