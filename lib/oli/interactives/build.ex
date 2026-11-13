defmodule Oli.Interactives.Build do
  @moduledoc "Durable state for a single Interactive authoring build."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "interactive_builds" do
    belongs_to :project, Oli.Authoring.Course.Project
    belongs_to :resource, Oli.Resources.Resource
    belongs_to :author, Oli.Accounts.Author
    field :lock_id, :integer
    field :status, :string, default: "queued"
    field :inputs, :map
    field :session_id, :string
    field :handoff, :map, default: %{}
    field :error, :string
    field :transcript, :string, default: ""
    timestamps(type: :utc_datetime_usec)
  end

  @doc "Validates persisted build attributes and enforces one active build per activity."
  def changeset(build, attrs) do
    build
    |> cast(attrs, [
      :project_id,
      :resource_id,
      :author_id,
      :lock_id,
      :status,
      :inputs,
      :session_id,
      :handoff,
      :error,
      :transcript
    ])
    |> validate_required([:project_id, :resource_id, :author_id, :lock_id, :status, :inputs])
    |> validate_inclusion(
      :status,
      ~w(queued launching running cancelling cancelled completed failed)
    )
    |> unique_constraint([:project_id, :resource_id], name: :interactive_builds_one_active)
  end
end
