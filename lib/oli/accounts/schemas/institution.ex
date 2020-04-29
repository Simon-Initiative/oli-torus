defmodule Oli.Accounts.Institution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "institutions" do
    field :country_code, :string
    field :institution_email, :string
    field :institution_url, :string
    field :name, :string
    field :timezone, :string
    field :consumer_key, :string
    field :shared_secret, :string
    belongs_to :author, Oli.Accounts.Author, foreign_key: :author_id
    has_many :sections, Oli.Delivery.Sections.Section
    has_many :users, Oli.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(institution, attrs \\ %{}) do
    institution
    |> cast(attrs, [
      :name,
      :country_code,
      :institution_email,
      :institution_url,
      :timezone,
      :consumer_key,
      :shared_secret,
      :author_id,
    ])
    |> validate_required([
      :name,
      :country_code,
      :institution_email,
      :institution_url,
      :timezone,
      :consumer_key,
      :shared_secret,
      :author_id
    ])
  end
end
