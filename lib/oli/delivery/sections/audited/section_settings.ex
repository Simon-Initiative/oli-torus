defmodule Oli.Delivery.Sections.Audited.SectionSettings do
  @moduledoc false
  # Settings of sections and products: edit forms, labels, cover image, agenda, institution,
  # required survey, DOT and instructor AI recommendations, and the publication update policy.
  #
  # Moved here:
  #   * `Sections.create_required_survey/1` and `Sections.delete_required_survey/1`, which wrote
  #     `required_survey_resource_id` directly.
  #
  # One save records one event per family that changed:
  #   * `<kind>_archived` or `<kind>_deleted` when the status moves to that value;
  #   * `<kind>_settings_changed` for the other section settings;
  #   * `publication_update_policy_changed` for `apply_major_updates`;
  #   * `dot_settings_changed`, `activation_settings_changed`, and
  #     `instructor_ai_recommendation_changed` for the DOT settings.
  # Payment, pricing, and certificate fields are written but not recorded until their own
  # events exist.

  alias Ecto.Multi
  alias Oli.Auditing.{Changes, Command, Context, DotPolicy}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionCache, SectionFields}
  alias Oli.Delivery.Sections.Audited.Support

  @dot_events [
    dot_settings_changed: [:assistant_enabled, :page_prompt_template],
    activation_settings_changed: [:triggers_enabled],
    instructor_ai_recommendation_changed: [
      :instructor_recommendations_enabled,
      :instructor_recommendation_prompt_template
    ]
  ]

  @dot_fields Enum.flat_map(@dot_events, fn {_event, fields} -> fields end)
  @prompt_fields [:page_prompt_template, :instructor_recommendation_prompt_template]

  # Recorded by their own events or by the discussion commands, not as section settings.
  @not_settings [:status, :apply_major_updates, :contains_discussions | @dot_fields]

  @doc "The DOT and instructor AI recommendation fields of a section."
  def dot_fields, do: @dot_fields

  @doc "The fields a settings form may write: audited settings other than DOT, and open ones."
  def settings_fields,
    do: (SectionFields.audited() -- @dot_fields) ++ SectionFields.open()

  @doc """
  Writes the keys of `attrs` named in `allowed` to `section` and records the families that
  changed. `allowed` must be a subset of `domain`; other keys of `attrs` are ignored.
  """
  def update(%Context{} = context, %Section{} = section, attrs, allowed, domain) do
    case allowed -- domain do
      [] -> write(context, section, SectionFields.take(attrs, allowed))
      _outside -> {:error, :invalid_request}
    end
  end

  def create_survey(context, %Section{required_survey_resource_id: nil} = section) do
    case Sections.get_base_project_survey(section.slug) do
      nil -> {:error, :no_project_survey}
      survey -> write(context, section, %{required_survey_resource_id: survey.resource_id})
    end
  end

  def create_survey(_context, _section), do: {:error, :survey_already_required}

  def delete_survey(_context, %Section{required_survey_resource_id: nil}),
    do: {:error, :no_required_survey}

  def delete_survey(context, section),
    do: write(context, section, %{required_survey_resource_id: nil})

  defp write(context, section, attrs) do
    result =
      Command.run(:section, fn multi ->
        multi
        |> Multi.run(:before, fn _repo, _changes -> Support.lock_section(section.id) end)
        |> Multi.run(:section, fn repo, %{before: before} ->
          before |> Sections.settings_changeset(attrs) |> repo.update()
        end)
        |> Multi.run(:events, fn _repo, %{before: before, section: updated} ->
          case Support.record_many(context, proposals(before, updated)) do
            :ok -> {:ok, nil}
            error -> error
          end
        end)
      end)

    with {:ok, updated} <- result do
      SectionCache.clear(updated.slug, [:ordered_container_labels])
      {:ok, Support.preload_like(updated, section)}
    end
  end

  # Event proposals

  defp proposals(before, updated) do
    status_proposals(before, updated) ++
      [
        settings_proposal(before, updated),
        publication_policy_proposal(before, updated)
      ] ++ dot_proposals(before, updated)
  end

  defp status_proposals(%Section{status: status}, %Section{status: status}), do: []

  defp status_proposals(_before, %Section{status: :deleted} = updated),
    do: [Support.lifecycle_proposal(updated, :deleted)]

  defp status_proposals(before, %Section{status: :archived} = updated) do
    [
      Support.lifecycle_proposal(updated, :archived, %{
        changes: Changes.diff(before, updated, %{status: :value})
      })
    ]
  end

  defp status_proposals(_before, _updated), do: []

  # A status that moves back to active is a settings change.
  defp settings_proposal(before, updated) do
    policy =
      Fields.section_settings()
      |> Map.drop(@not_settings)
      |> Map.merge(reactivation_policy(updated))

    Support.lifecycle_proposal(updated, :settings_changed, %{
      changes: Changes.diff(before, updated, policy)
    })
  end

  defp reactivation_policy(%Section{status: :active}), do: %{status: :value}
  defp reactivation_policy(_section), do: %{}

  defp publication_policy_proposal(before, updated) do
    entity_proposal(updated, :publication_update_policy_changed, %{
      changes: Changes.diff(before, updated, %{apply_major_updates: :value})
    })
  end

  defp dot_proposals(before, updated) do
    Enum.map(@dot_events, fn {event_type, fields} ->
      {changes, truncated?} =
        before
        |> Changes.diff(updated, Map.new(fields, &{&1, :value}))
        |> truncate_prompts()

      details =
        case truncated? do
          true -> %{prompt_truncated: true}
          false -> %{}
        end

      entity_proposal(updated, event_type, %{changes: changes, details: details})
    end)
  end

  # Prompts are recorded up to the length `DotPolicy` allows.
  defp truncate_prompts(changes) do
    Enum.reduce(@prompt_fields, {changes, false}, fn field, {changes, truncated?} ->
      case Map.fetch(changes, Atom.to_string(field)) do
        {:ok, record} ->
          {record, cut?} = truncate_record(record)
          {Map.put(changes, Atom.to_string(field), record), truncated? or cut?}

        :error ->
          {changes, truncated?}
      end
    end)
  end

  defp truncate_record(record) do
    Enum.reduce(["before", "after"], {record, false}, fn side, {record, truncated?} ->
      case Map.fetch(record, side) do
        {:ok, prompt} ->
          {prompt, cut?} = DotPolicy.truncate_prompt(prompt)
          {Map.put(record, side, prompt), truncated? or cut?}

        :error ->
          {record, truncated?}
      end
    end)
  end

  defp entity_proposal(%Section{id: id} = section, event_type, attrs) do
    kind = Support.kind(section)

    Map.merge(
      %{
        event_type: event_type,
        entity: {kind, id, section},
        scope: Support.scope(section),
        event_key: "#{kind}:#{id}:#{event_type}"
      },
      attrs
    )
  end
end
