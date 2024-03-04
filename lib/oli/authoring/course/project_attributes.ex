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

  def changeset(%ProjectAttributes{} = attributes, attrs \\ %{}) do
    attributes
    |> cast(attrs, [:learning_language])
    |> cast_embed(:license, required: false)
  end
end

defmodule Oli.Authoring.Course.ProjectAttributes.License do
  use Ecto.Schema
  alias Oli.Authoring.Course.CreativeCommons
  import Ecto.Changeset
  import Oli.Utils
  alias __MODULE__

  @license_opts CreativeCommons.cc_options() |> Enum.map(& &1.id)

  @primary_key false
  embedded_schema do
    field(:license_type, Ecto.Enum, values: @license_opts, default: :none)
    field(:custom_license_details, :string, default: "")
  end

  def changeset(%License{} = license, attrs \\ %{}) do
    license
    |> cast(attrs, [:license_type, :custom_license_details])
    |> validate_required_if([:custom_license_details], &is_custom?/1)
  end

  defp is_custom?(changeset) do
    get_field(changeset, :license_type) == :custom
  end
end
