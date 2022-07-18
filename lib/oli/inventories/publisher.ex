defmodule Oli.Inventories.Publisher do
  use Ecto.Schema
  import Ecto.Changeset
  import Oli.Utils

  @derive {Jason.Encoder, only: [:id, :name, :email, :address, :main_contact, :website_url]}

  schema "publishers" do
    field :name, :string
    field :email, :string
    field :address, :string
    field :main_contact, :string
    field :website_url, :string
    field :default, :boolean, default: false
    field :available_via_api, :boolean, default: true

    has_many :products, Oli.Delivery.Sections.Section
    has_many :projects, Oli.Authoring.Course.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(publisher, attrs \\ %{}) do
    publisher
    |> cast(attrs, [
      :name,
      :email,
      :address,
      :main_contact,
      :website_url,
      :default,
      :available_via_api
    ])
    |> validate_required([:name, :email, :default])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:name)
    |> unique_constraint_if([:default], &is_default?/1,
      name: :publisher_default_true_index,
      message: "there must only be one default"
    )
  end

  defp is_default?(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true} = changeset ->
        get_field(changeset, :default)

      _ ->
        false
    end
  end
end
