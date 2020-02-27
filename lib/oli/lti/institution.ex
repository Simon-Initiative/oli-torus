defmodule Oli.Lti.Institution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "institutions" do
    field :country_code, :string
    field :institution_email, :string
    field :institution_url, :string
    field :name, :string
    field :timezone, :string

    timestamps()
  end

  @doc false
  def changeset(institution, attrs) do
    institution
    |> cast(attrs, [:country_code, :institution_email, :institution_url, :name, :timezone])
    |> validate_required([:country_code, :institution_email, :institution_url, :name, :timezone])
  end
end
