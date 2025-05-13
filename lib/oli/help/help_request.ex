defmodule Oli.Help.HelpRequest do
  use Ecto.Schema
  import Ecto.Changeset
  import Oli.Utils

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :name, :string
    field :email_address, :string
    field :subject, :string
    field :message, :string
    field :captcha, :string, virtual: true
    field :requires_sender_data, :boolean, default: false

    timestamps()
  end

  def changeset(params \\ %{}) do
    changeset(%__MODULE__{}, params)
  end

  @doc false
  def changeset(help_request, attrs) do
    help_request
    |> cast(attrs, [:subject, :message, :name, :email_address, :requires_sender_data, :captcha])
    |> validate_required([:subject, :message, :requires_sender_data])
    |> validate_required_if([:name, :email_address], &requires_sender_data?/1)
    |> validate_inclusion(:subject, Oli.Help.HelpContent.list_subjects() |> Map.keys())
  end

  defp requires_sender_data?(changeset) do
    get_field(changeset, :requires_sender_data)
  end
end
