defmodule Oli.Auditing.LegacyAdapter do
  @moduledoc false
  # Temporary bridge between the 16 existing producers and the version 2 event contracts.
  #
  # Those producers call `Oli.Auditing.capture/4` with the legacy
  # `(actor, event_type, resource, details)` shape, after their domain change has committed.
  # The new storage only accepts complete version 2 rows (entity, scope, affected person,
  # event key, changes), so this module derives them from what the caller already passes. The
  # call sites stay unchanged and every row they write still satisfies its contract.
  #
  # The producers are not moved to the new API here on purpose. Their target is to write the
  # event inside the same transaction as the domain change (`Oli.Auditing.append/3` in an
  # `Ecto.Multi`), which means reshaping each domain's transaction. Each later coverage
  # sub-task does that for its own events, so each call site changes only once:
  #
  #   * boundary pilot: `user_deleted`
  #   * identity and platform administration: `author_deleted`, `author_role_changed`,
  #     `account_internal_flag_changed`, and the feature flag and rollout events
  #   * authoring and projects: `project_published`, `google_doc_imported`
  #   * delivery and configuration: `section_created`
  #   * learner administration and operations: `resource_attempt_deleted`,
  #     `clickhouse_admin_operation_initiated`
  #
  # The mapping never invents data. It uses only the actor, resource, and details it receives,
  # rejects what it cannot map (for example a nil actor) with `:invalid_event`, and drops detail
  # keys outside the event's contract (such as the legacy `admin_action` marker). Every event is
  # recorded with source `:application`, a new operation ID, and outcome `:succeeded`, except
  # `clickhouse_admin_operation_initiated` (`:initiated`).
  #
  # Removal gate: final acceptance verifies that no caller still depends on this module without
  # the audited coordinator guarantees, and then removes it.

  alias Oli.Accounts.{Author, User}
  alias Oli.Auditing.{Context, EventCatalog}
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section

  @events ~w(user_deleted author_deleted author_role_changed project_published section_created
    feature_flag_enabled feature_flag_disabled feature_flag_removed google_doc_imported
    feature_rollout_stage_changed feature_rollout_stage_deleted feature_rollout_exemption_upserted
    feature_rollout_exemption_deleted account_internal_flag_changed
    clickhouse_admin_operation_initiated resource_attempt_deleted)a

  @global_scope %{role: :scope, type: :global, id: "global", label: "All institutions"}

  @doc false
  def events, do: @events

  @doc false
  @spec to_proposal(term(), atom(), term(), map()) ::
          {:ok, Context.t(), map()} | {:error, :invalid_event}
  def to_proposal(actor, event_type, resource, details)
      when event_type in @events and is_map(details) do
    with {:ok, context} <- context(actor),
         {:ok, details} <- json_details(details),
         {:ok, proposal} <- proposal(event_type, resource, details) do
      contract = EventCatalog.contract!(event_type)

      proposal =
        proposal
        |> Map.put(:event_type, event_type)
        |> Map.put(:details, Map.take(details, contract.detail_keys))
        |> Map.put_new(:outcome, :succeeded)

      {:ok, context, proposal}
    end
  end

  def to_proposal(_actor, _event_type, _resource, _details), do: {:error, :invalid_event}

  defp context(%User{id: id} = user) when is_integer(id),
    do: {:ok, Context.for_actor(user, source: :application)}

  defp context(%Author{id: id} = author) when is_integer(id),
    do: {:ok, Context.for_actor(author, source: :application)}

  defp context(_actor), do: {:error, :invalid_event}

  # Legacy details may hold atoms or dates; the envelope only stores JSON-native values.
  defp json_details(details) do
    {:ok, details |> Jason.encode!() |> Jason.decode!()}
  rescue
    _ in [Jason.EncodeError, Protocol.UndefinedError] -> {:error, :invalid_event}
  end

  defp proposal(event, %struct{id: id} = account, _details)
       when event in [:user_deleted, :author_deleted] and struct in [User, Author] do
    kind = account_kind(struct)

    {:ok,
     %{
       entity: {kind, id, account},
       affected: {kind, id},
       event_key: "account:primary:deleted"
     }}
  end

  defp proposal(:author_role_changed, %Author{id: id} = author, details) do
    {:ok,
     %{
       entity: {:author, id, author},
       affected: {:author, id},
       event_key: "account:primary:author_role_changed",
       changes: set_change("system_role_id", details["previous_role_id"], details["new_role_id"])
     }}
  end

  defp proposal(:account_internal_flag_changed, %struct{id: id} = account, details)
       when struct in [User, Author] do
    kind = account_kind(struct)

    {:ok,
     %{
       entity: {kind, id, account},
       affected: {kind, id},
       event_key: "account:primary:account_internal_flag_changed",
       changes: set_change("is_internal", details["previous"], details["is_internal"])
     }}
  end

  defp proposal(:project_published, %Project{id: id} = project, details) do
    refs =
      case details["publication_id"] do
        publication_id when is_integer(publication_id) ->
          [ref(:resulting, :publication, publication_id, details["version"])]

        _ ->
          []
      end

    {:ok,
     %{
       entity: {:project, id, project},
       scope: %{project_id: id},
       refs: refs,
       event_key: "project:#{id}:published"
     }}
  end

  defp proposal(:google_doc_imported, %Project{id: id} = project, details) do
    scope =
      case details["page_resource_id"] do
        resource_id when is_integer(resource_id) -> %{project_id: id, resource_id: resource_id}
        _ -> %{project_id: id}
      end

    {:ok,
     %{
       entity: {:project, id, project},
       scope: scope,
       event_key: "project:#{id}:google_doc_imported"
     }}
  end

  defp proposal(:section_created, %Section{id: id} = section, details) do
    scope =
      %{
        section_id: id,
        project_id: details["base_project_id"] || section.base_project_id,
        institution_id: section.institution_id
      }
      |> Map.reject(fn {_column, value} -> not is_integer(value) end)

    {:ok, %{entity: {:section, id, section}, scope: scope, event_key: "section:#{id}:created"}}
  end

  defp proposal(:resource_attempt_deleted, _section, %{"attempt_guid" => guid} = details)
       when is_binary(guid) do
    scope =
      %{section_id: details["section_id"], resource_id: details["resource_id"]}
      |> Map.reject(fn {_column, value} -> not is_integer(value) end)

    {:ok,
     %{
       entity: {:resource_attempt, guid, %{}},
       scope: scope,
       affected: {:user, details["user_id"]},
       event_key: "attempt:#{key_segment(guid)}:deleted"
     }}
  end

  defp proposal(event, resource, %{"feature_name" => feature} = _details)
       when event in [:feature_flag_enabled, :feature_flag_disabled, :feature_flag_removed] and
              is_binary(feature) do
    {scope, refs} =
      case resource do
        %Project{id: id} -> {%{project_id: id}, []}
        %Section{id: id} -> {%{section_id: id}, []}
        _ -> {%{}, [@global_scope]}
      end

    {:ok,
     %{
       entity: {:feature_flag, feature, %{}},
       scope: scope,
       refs: refs,
       event_key: "flag:#{key_segment(feature)}:#{event}"
     }}
  end

  defp proposal(
         event,
         _resource,
         %{"feature_name" => feature, "scope_type" => scope_type} = details
       )
       when event in [:feature_rollout_stage_changed, :feature_rollout_stage_deleted] and
              is_binary(feature) do
    {scope, refs, scope_key} = rollout_scope(scope_type, details["scope_id"])
    action = event |> Atom.to_string() |> String.replace_prefix("feature_rollout_", "")

    {:ok,
     %{
       entity: {:feature_rollout, feature, %{}},
       scope: scope,
       refs: refs,
       event_key: "rollout:#{key_segment(feature)}:#{scope_key}:#{action}"
     }}
  end

  defp proposal(event, _resource, %{"feature_name" => feature, "publisher_id" => publisher_id})
       when event in [:feature_rollout_exemption_upserted, :feature_rollout_exemption_deleted] and
              is_binary(feature) and is_integer(publisher_id) do
    action = event |> Atom.to_string() |> String.replace_prefix("feature_rollout_", "")

    {:ok,
     %{
       entity: {:rollout_exemption, "#{feature}:publisher:#{publisher_id}", %{}},
       refs: [ref(:scope, :publisher, publisher_id, nil)],
       event_key: "rollout:#{key_segment(feature)}:publisher_#{publisher_id}:#{action}"
     }}
  end

  defp proposal(:clickhouse_admin_operation_initiated, _resource, details) do
    case details do
      %{"operation_id" => operation_id, "kind" => kind} when is_binary(kind) ->
        {:ok,
         %{
           entity: {:clickhouse_operation, operation_id, %{label: details["operation_label"]}},
           outcome: :initiated,
           event_key: "clickhouse:#{key_segment(kind)}:initiated"
         }}

      _ ->
        {:error, :invalid_event}
    end
  end

  defp proposal(_event, _resource, _details), do: {:error, :invalid_event}

  defp rollout_scope("project", id) when is_integer(id),
    do: {%{project_id: id}, [], "project_#{id}"}

  defp rollout_scope("section", id) when is_integer(id),
    do: {%{section_id: id}, [], "section_#{id}"}

  defp rollout_scope(_global, _id), do: {%{}, [@global_scope], "global"}

  defp set_change(field, before, after_value),
    do: %{field => %{"operation" => "set", "before" => before, "after" => after_value}}

  defp ref(role, type, id, nil), do: %{role: role, type: type, id: id}
  defp ref(role, type, id, label), do: %{role: role, type: type, id: id, label: label}

  defp account_kind(User), do: :user
  defp account_kind(Author), do: :author

  # Event key segments only allow lowercase letters, digits, underscores, and hyphens.
  defp key_segment(value),
    do: value |> to_string() |> String.downcase() |> String.replace(~r/[^a-z0-9_\-]/, "_")
end
