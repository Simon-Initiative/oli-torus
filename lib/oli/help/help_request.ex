defmodule Oli.Help.HelpRequest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "help_requests" do
    field :subject, :string
    field :message, :string
    field :location, :string
    field :cookies_enabled, :boolean
    field :captcha, :string, virtual: true

    timestamps()
  end

  @doc false
  def changeset(help_request, attrs) do
    help_request
    |> cast(attrs, [:subject, :message, :location, :cookies_enabled, :captcha])
    |> validate_required([:subject, :message, :location, :cookies_enabled])
  end
end
