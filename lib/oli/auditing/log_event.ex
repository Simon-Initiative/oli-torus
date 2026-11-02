defmodule Oli.Auditing.LogEvent do
  @moduledoc """
  One row of the append-only `audit_log_events` table, partitioned by half-year on
  `inserted_at`.

  ## Field glossary

    * `id`, `inserted_at` - the primary key. `inserted_at` is when the row was recorded and is
      the partition key; date filters and sorting use it. `get_event!/2` uses both to read a
      single partition.
    * `occurred_at` - when the action happened. It differs from `inserted_at` only for
      late-recorded async outcomes. `nil` on migrated history (unknown).
    * `schema_version` - `2` for every application event (forced by `v2_changeset/2`); `1` for
      history migrated from the legacy tables, where unknown values stay `nil`.
    * `event_type` - a name from `Oli.Auditing.EventCatalog`, which also provides its family,
      label, description, and contract.
    * `outcome` - `succeeded`, `initiated`, `failed`, `canceled`, `partial`, or `unknown`.
    * `actor_type`, `user_id`, `author_id`, `actor_key`, `actor_snapshot` - who acted: exactly
      one user, author, or system actor (`unknown` only on migrated history). The snapshot keeps
      the actor's identity at the time of the event.
    * `entity_type`, `entity_id`, `entity_snapshot` - the record the event is about. Composite
      IDs are built with `Oli.Auditing.EntityId`.
    * `affected_user_id`, `affected_author_id` - the person the action was applied to, when
      different from the actor (for example, the student of a student exception).
    * `project_id`, `section_id`, `resource_id`, `institution_id` - scope. A scope record known
      to the event always goes in its column, never only in `refs` or `details`.
    * `refs` - other typed references: `%{"role", "type", "id", "label"}`.
    * `changes` - per-field change records (`Oli.Auditing.Changes`), at most 64 KiB serialized.
    * `details` - event-specific context, allowlisted per event.
    * `source`, `operation_id`, `parent_operation_id`, `event_key` - where the change came from,
      the command it belongs to, and the event's key within that command.
    * `legacy_source`, `legacy_id` - provenance of migrated history.
    * `search_text` - text indexed for search, built only from snapshots and reference labels.

  No column has a foreign key, so events stay readable after their records are deleted.

  The snapshots, `refs`, `changes`, `details`, and `search_text` are redacted when an event or its
  changeset is inspected, so logging a failed write does not copy names, emails, or values.

  ## Examples

  A bulk student-exception update: an instructor changes two students' due dates in one
  command. Each student gets one row; both rows share `operation_id` and differ by
  `event_key`.

      %{event_type: :student_exception_updated, actor_type: :user, user_id: 41,
        entity_type: :student_exception, entity_id: "section:301/resource:4512/user:77",
        affected_user_id: 77, section_id: 301, resource_id: 4512, outcome: :succeeded,
        operation_id: "6f1c...", event_key: "student_exception:301:4512:77:updated",
        changes: %{"end_date" => %{"operation" => "set", "before" => "...", "after" => "..."}}}

  A system-provisioned account: no person acted, so the actor is a fixed system key.

      %{event_type: :account_created, actor_type: :system, actor_key: "provider_provisioning",
        actor_snapshot: %{"key" => "provider_provisioning",
                          "label" => "Identity provider provisioning"},
        entity_type: :user, entity_id: "77", affected_user_id: 77, source: :system}

  A migrated v1 row: only what the legacy table knew is set.

      %{schema_version: 1, event_type: :project_published, actor_type: :author, author_id: 12,
        project_id: 88, legacy_source: :audit_log_events, legacy_id: 1450,
        occurred_at: nil, outcome: nil, operation_id: nil}
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Auditing.{Context, EventCatalog}
  alias Oli.Auditing.EventCatalog.Validation

  @entity_types EventCatalog.contracts() |> Enum.flat_map(& &1.entity_types) |> Enum.uniq()

  @v2_fields [
    :inserted_at,
    :occurred_at,
    :event_type,
    :outcome,
    :actor_type,
    :actor_key,
    :user_id,
    :author_id,
    :actor_snapshot,
    :entity_type,
    :entity_id,
    :entity_snapshot,
    :affected_user_id,
    :affected_author_id,
    :project_id,
    :section_id,
    :resource_id,
    :institution_id,
    :refs,
    :changes,
    :details,
    :source,
    :operation_id,
    :parent_operation_id,
    :event_key,
    :search_text
  ]

  @type t :: %__MODULE__{}

  @primary_key false
  schema "audit_log_events" do
    field :id, :id, primary_key: true, read_after_writes: true
    field :inserted_at, :utc_datetime_usec, primary_key: true
    field :occurred_at, :utc_datetime_usec
    field :schema_version, :integer
    field :event_type, Ecto.Enum, values: EventCatalog.names()
    field :outcome, Ecto.Enum, values: Validation.outcomes()
    field :actor_type, Ecto.Enum, values: [:user, :author, :system, :unknown]
    field :actor_key, :string
    field :user_id, :integer
    field :author_id, :integer
    field :actor_snapshot, :map, default: %{}, redact: true
    field :entity_type, Ecto.Enum, values: @entity_types
    field :entity_id, :string
    field :entity_snapshot, :map, default: %{}, redact: true
    field :affected_user_id, :integer
    field :affected_author_id, :integer
    field :project_id, :integer
    field :section_id, :integer
    field :resource_id, :integer
    field :institution_id, :integer
    field :refs, {:array, :map}, default: [], redact: true
    field :changes, :map, default: %{}, redact: true
    field :details, :map, default: %{}, redact: true
    field :source, Ecto.Enum, values: Context.sources()
    field :operation_id, Ecto.UUID
    field :parent_operation_id, Ecto.UUID
    field :event_key, :string
    field :legacy_source, Ecto.Enum, values: [:audit_log_events, :settings_changes]
    field :legacy_id, :integer
    field :search_text, :string, default: "", redact: true
    # Generated by the database from search_text; only referenced in search queries.
    field :search_vector, :string, writable: :never, load_in_query: false

    # Display-only values loaded by the readers.
    field :actor, :any, virtual: true
    field :resource, :any, virtual: true
    field :total_count, :integer, virtual: true
  end

  @doc """
  The only application changeset. Forces `schema_version` to 2 and validates the row against
  the envelope rules and its event contract (`Oli.Auditing.EventCatalog.validate/1`).

  An empty change set on a `:skip` contract adds a `:changes` error with
  `validation: :no_changes`, which `Oli.Auditing.build/2` reports as `{:error, :no_changes}`.
  """
  @spec v2_changeset(t(), map()) :: Ecto.Changeset.t()
  def v2_changeset(%__MODULE__{} = event, attrs) do
    event
    |> cast(attrs, @v2_fields)
    |> put_change(:schema_version, 2)
    |> validate_contract()
  end

  defp validate_contract(changeset) do
    attrs = changeset |> apply_changes() |> Map.from_struct()
    cast_errors = Keyword.keys(changeset.errors)

    case EventCatalog.validate(attrs) do
      :ok ->
        changeset

      {:error, :no_changes} ->
        add_error(changeset, :changes, "has no changes", validation: :no_changes)

      {:error, errors} ->
        errors
        |> Enum.reject(fn {column, _message} -> column in cast_errors end)
        |> Enum.reduce(changeset, fn {column, message}, acc ->
          add_error(acc, column, message, validation: :contract)
        end)
    end
  end

  @doc """
  Returns the display name of the actor: the loaded account, then the stored snapshot, then
  the account ID. System actors show their label; migrated rows without an actor show
  "Unknown".
  """
  @spec actor_name(t()) :: String.t()
  def actor_name(%__MODULE__{actor_type: :system, actor_snapshot: snapshot, actor_key: key}),
    do: Map.get(snapshot || %{}, "label") || key || "System"

  def actor_name(%__MODULE__{} = event) do
    with nil <- display_name(event.actor),
         nil <- display_name(event.actor_snapshot) do
      account_label(event)
    end
  end

  defp display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{email: email}) when is_binary(email) and email != "", do: email
  defp display_name(%{"name" => name}) when is_binary(name) and name != "", do: name
  defp display_name(%{"email" => email}) when is_binary(email) and email != "", do: email
  defp display_name(_), do: nil

  defp account_label(%{user_id: id}) when is_integer(id), do: "User ##{id}"
  defp account_label(%{author_id: id}) when is_integer(id), do: "Author ##{id}"
  defp account_label(_event), do: "Unknown"

  @doc """
  Returns a one-line description of the event for the admin list. Events captured before the
  catalog keep their detail-based descriptions; every other event uses its catalog label.
  """
  @spec event_description(t()) :: String.t()
  def event_description(%__MODULE__{} = event) do
    case event.event_type do
      :user_deleted ->
        "Deleted user account"

      :author_deleted ->
        "Deleted author account"

      :author_role_changed ->
        "#{event.details["previous_role"]} → #{event.details["new_role"]}"

      :project_published ->
        "Published project #{get_in(event.details, ["project_title"]) || ""}"

      :section_created ->
        "Created section #{get_in(event.details, ["section_title"]) || ""}"

      :feature_flag_enabled ->
        feature_name = get_in(event.details, ["feature_name"]) || "unknown"
        resource_type = get_in(event.details, ["resource_type"]) || "resource"
        "Enabled feature flag '#{feature_name}' for #{resource_type}"

      :feature_flag_disabled ->
        feature_name = get_in(event.details, ["feature_name"]) || "unknown"
        resource_type = get_in(event.details, ["resource_type"]) || "resource"
        "Disabled feature flag '#{feature_name}' for #{resource_type}"

      :feature_flag_removed ->
        feature_name = get_in(event.details, ["feature_name"]) || "unknown"
        resource_type = get_in(event.details, ["resource_type"]) || "resource"
        "Removed feature flag '#{feature_name}' from #{resource_type}"

      :google_doc_imported ->
        page_title = get_in(event.details, ["page_title"]) || ""
        "Imported Google Doc into page #{page_title}"

      :feature_rollout_stage_changed ->
        feature = get_in(event.details, ["feature_name"]) || "unknown feature"
        scope_type = get_in(event.details, ["scope_type"]) || "scope"

        to_stage =
          get_in(event.details, ["stage"]) || get_in(event.details, ["to_stage"]) || "stage"

        "Updated rollout for #{feature} (#{scope_type}) to #{to_stage}"

      :feature_rollout_stage_deleted ->
        feature = get_in(event.details, ["feature_name"]) || "unknown feature"
        scope_type = get_in(event.details, ["scope_type"]) || "scope"
        "Removed rollout for #{feature} (#{scope_type})"

      :feature_rollout_exemption_upserted ->
        feature = get_in(event.details, ["feature_name"]) || "unknown feature"
        effect = get_in(event.details, ["effect"]) || "effect"
        "Updated exemption for #{feature} (#{effect})"

      :feature_rollout_exemption_deleted ->
        feature = get_in(event.details, ["feature_name"]) || "unknown feature"
        "Removed exemption for #{feature}"

      :account_internal_flag_changed ->
        account_type = get_in(event.details, ["account_type"]) || "account"

        status =
          case get_in(event.details, ["is_internal"]) do
            true -> "internal"
            _ -> "external"
          end

        "Updated internal flag for #{account_type} (#{status})"

      :clickhouse_admin_operation_initiated ->
        operation = get_in(event.details, ["operation_label"]) || "ClickHouse operation"
        "#{operation} initiated"

      event_type ->
        EventCatalog.label(event_type)
    end
  end

  @doc "Returns every event type accepted by the catalog."
  @spec event_types() :: [atom()]
  def event_types, do: EventCatalog.names()
end
