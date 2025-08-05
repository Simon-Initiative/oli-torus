defmodule Oli.Inventories.Publisher do
  use Ecto.Schema
  import Ecto.Changeset
  import Oli.Utils

  @moduledoc """
  The Publisher schema represents a content publisher in the system.

  ## Fields

  - `knowledge_base_link`: (string) Optional. The URL to the publisher’s knowledge base or support documentation. Used for routing help modal links. If blank, the system falls back to the global default.
  - `support_email`: (string) Optional. The support email address for this publisher. Used for routing help requests. Must be a valid email (must contain `@` and no spaces). If blank, the system falls back to the global default.
  """

  @derive {Jason.Encoder, only: [:id, :name, :email, :address, :main_contact, :website_url]}

  schema "publishers" do
    field :name, :string
    field :email, :string
    field :address, :string
    field :main_contact, :string
    field :website_url, :string
    field :default, :boolean, default: false
    field :available_via_api, :boolean, default: true
    field :knowledge_base_link, :string
    field :support_email, :string

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
      :available_via_api,
      :knowledge_base_link,
      :support_email
    ])
    |> validate_required([:name, :email, :default])
    |> validate_format(:email, ~r/@/)
    |> maybe_validate_support_email()
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

  defp maybe_validate_support_email(changeset) do
    support_email = get_field(changeset, :support_email)

    if is_binary(support_email) and String.trim(support_email) != "" do
      validate_format(changeset, :support_email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
        message: "must have the @ sign and no spaces"
      )
    else
      changeset
    end
  end
end
