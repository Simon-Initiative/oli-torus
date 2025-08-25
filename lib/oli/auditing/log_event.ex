defmodule Oli.Auditing.LogEvent do
  use Ecto.Schema
  import Ecto.Changeset

  # The following are event types that are initiated by user actions,
  # either from an Author or a User (intructor).  Eventually we may
  # introduce "user-less" event types, things that the system is doing
  # itself (like automated fallback of a primary registered LLM model
  # to a backup one). These could be represented by BOTH user_id and
  # author_id being nil. We'd have to also consider updating the filter
  # in the UI to account for System events.
  @event_types [
    :user_deleted,
    :author_deleted,
    :project_published,
    :section_created
  ]

  schema "audit_log_events" do
    field :user_id, :integer
    field :author_id, :integer
    field :event_type, Ecto.Enum, values: @event_types
    field :section_id, :integer
    field :project_id, :integer
    field :resource_id, :integer
    field :details, :map, default: %{}

    # Virtual fields for actor polymorphism
    field :actor, :any, virtual: true
    field :resource, :any, virtual: true
    field :total_count, :integer, virtual: true

    timestamps(updated_at: false, type: :utc_datetime)
  end

  @doc false
  def changeset(log_event, attrs) do
    log_event
    |> cast(attrs, [
      :user_id,
      :author_id,
      :event_type,
      :section_id,
      :project_id,
      :resource_id,
      :details
    ])
    |> validate_required([:event_type])
    |> validate_inclusion(:event_type, @event_types)
    |> validate_actor()
  end

  # Ensure at least one actor is present for non-system events
  defp validate_actor(changeset) do
    user_id = get_field(changeset, :user_id)
    author_id = get_field(changeset, :author_id)
    event_type = get_field(changeset, :event_type)

    # Allow system events without an actor
    system_events = []

    if is_nil(user_id) and is_nil(author_id) and event_type not in system_events do
      add_error(changeset, :base, "either user_id or author_id must be present")
    else
      changeset
    end
  end

  @doc """
  Returns the formatted actor name for display purposes.
  """
  def actor_name(%__MODULE__{} = event) do
    cond do
      event.user_id && event.actor ->
        case event.actor do
          %{name: name} when not is_nil(name) and name != "" -> name
          %{email: email} -> email
          _ -> "User ##{event.user_id}"
        end

      event.author_id && event.actor ->
        case event.actor do
          %{name: name} when not is_nil(name) and name != "" -> name
          %{email: email} -> email
          _ -> "Author ##{event.author_id}"
        end

      event.user_id ->
        "User ##{event.user_id}"

      event.author_id ->
        "Author ##{event.author_id}"

      true ->
        "System"
    end
  end

  @doc """
  Returns a human-readable description of the event.
  """
  def event_description(%__MODULE__{} = event) do
    case event.event_type do
      :user_deleted ->
        "Deleted user account"

      :author_deleted ->
        "Deleted author account"

      :project_published ->
        "Published project #{get_in(event.details, ["project_title"]) || ""}"

      :section_created ->
        "Created section #{get_in(event.details, ["section_title"]) || ""}"

      _ ->
        "#{event.event_type}"
    end
  end

  @doc """
  Returns the list of valid event types.
  """
  def event_types, do: @event_types
end
