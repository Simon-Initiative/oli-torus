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

# |> validate_required([:subject, :message, :location, :cookies_enabled])
# |> cast(attrs, [:subject, :message])
# |> cast(attrs, [:subject, :message, :current_location, :cookies_enabled, :captcha])
# field :issuer, :string
# field :email, :string
# field :course_section, :string
# field :current_location, :string
# user_account_link
# role
# user_agent_string
# browser_name
# browser_version
# operating_system
# device_type, :mobile, :tablet, :desktop
# screen_size
# ip_address
# browser_plugins
# field :cookies_enabled, :boolean
# js_enabled
