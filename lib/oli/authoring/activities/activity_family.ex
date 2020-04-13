defmodule Oli.Authoring.Activities.ActivityFamily do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_families" do

    timestamps()
  end

  @doc false
  def changeset(activity_family, attrs) do
    activity_family
    |> cast(attrs, [])
    |> validate_required([])
  end

end
