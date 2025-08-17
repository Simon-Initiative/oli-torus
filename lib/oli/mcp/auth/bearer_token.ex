defmodule Oli.MCP.Auth.BearerToken do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          author_id: integer(),
          project_id: integer(),
          hash: binary(),
          hint: String.t() | nil,
          status: String.t(),
          last_used_at: DateTime.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @statuses ~w(enabled disabled)

  schema "mcp_bearer_tokens" do
    field :hash, :binary
    field :hint, :string
    field :status, :string, default: "enabled"
    field :last_used_at, :utc_datetime

    belongs_to :author, Oli.Accounts.Author
    belongs_to :project, Oli.Authoring.Course.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bearer_token, attrs) do
    bearer_token
    |> cast(attrs, [:hash, :hint, :status, :last_used_at, :author_id, :project_id])
    |> validate_required([:hash, :status, :author_id, :project_id])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:author_id)
    |> foreign_key_constraint(:project_id)
    |> unique_constraint([:author_id, :project_id],
      message: "Author can only have one token per project"
    )
  end

  @doc """
  Returns the list of valid statuses for bearer tokens.
  """
  def statuses, do: @statuses

  @doc """
  Returns true if the token is enabled.
  """
  def enabled?(%__MODULE__{status: status}), do: status == "enabled"

  @doc """
  Returns true if the token is disabled.
  """
  def disabled?(%__MODULE__{status: status}), do: status == "disabled"
end
