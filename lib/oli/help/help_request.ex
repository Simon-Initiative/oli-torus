defmodule Oli.Help.HelpRequest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "help" do
    field :subject, :string
    field :message, :string
    field :captcha, :string, virtual: true

    timestamps()
  end

  def changeset(params \\ %{}) do
    changeset(%__MODULE__{}, params)
  end

  @doc false
  def changeset(help_request, attrs) do
    help_request
    |> cast(attrs, [:subject, :message, :captcha])
    |> validate_required([:subject, :message])
    |> validate_inclusion(:subject, Oli.Help.HelpContent.list_subjects() |> Map.keys())
  end
end
