defmodule Oli.Qa.Review do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reviews" do
    belongs_to :project, Oli.Authoring.Course.Project
    has_many :warnings, Oli.Qa.Warning, on_delete: :delete_all
    field :type, :string
    field :done, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(struct, attrs \\ %{}) do
    struct
    |> cast(attrs, ~w(project_id type done)a)
    |> validate_required(~w(project_id type)a)
  end
end
