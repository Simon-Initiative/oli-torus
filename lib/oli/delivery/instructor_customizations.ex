defmodule Oli.Delivery.InstructorCustomizations do
  @moduledoc """
  Delivery-owned instructor customization state for section page activities.

  This context owns customization reads, writes, authorization, and target
  validation.
  """

  import Ecto.Query, warn: false

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Accounts.User
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Delivery.InstructorCustomizations.ActivityExclusion
  alias Oli.Delivery.InstructorCustomizations.PageExclusions
  alias Oli.Delivery.InstructorCustomizations.TargetResolver
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Resources.Revision
  alias Oli.Repo

  @default_candidate_limit 25

  @doc """
  Duplicates all activity exclusions from one section to another.

  This is used when a template/blueprint is duplicated into a new section so
  template-owned exclusions are inherited without changing authored content.
  """
  def duplicate_section_exclusions(source_section_or_id, destination_section_or_id) do
    source_section_id = section_id(source_section_or_id)
    destination_section_id = section_id(destination_section_or_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query =
      from(exclusion in ActivityExclusion,
        where: exclusion.section_id == ^source_section_id,
        select: %{
          section_id: ^destination_section_id,
          page_resource_id: exclusion.page_resource_id,
          selection_id: exclusion.selection_id,
          kind: exclusion.kind,
          excluded_resource_id: exclusion.excluded_resource_id,
          inserted_at: ^now,
          updated_at: ^now
        }
      )

    {count, _} = Repo.insert_all(ActivityExclusion, query, on_conflict: :nothing)

    {:ok, count}
  end

  # Reads

  @doc """
  Returns raw exclusions for trusted internal callers.

  UI and transport callers must perform section authorization before using this
  function.
  """
  def get_page_exclusions(section_or_id, page_resource_id) when is_integer(page_resource_id) do
    section_id = section_id(section_or_id)

    from(exclusion in ActivityExclusion,
      where:
        exclusion.section_id == ^section_id and
          exclusion.page_resource_id == ^page_resource_id,
      order_by: exclusion.id
    )
    |> Repo.all()
  end

  @doc """
  Returns a compact page exclusion view for trusted internal callers.

  UI and transport callers must perform section authorization before using this
  function. Delivery lifecycle code can use it after resolving its trusted
  section context.
  """
  def get_page_exclusion_view(section_or_id, page_resource_id)
      when is_integer(page_resource_id) do
    section_id = section_id(section_or_id)

    from(exclusion in ActivityExclusion,
      where:
        exclusion.section_id == ^section_id and
          exclusion.page_resource_id == ^page_resource_id,
      select: struct(exclusion, [:kind, :selection_id, :excluded_resource_id])
    )
    |> Repo.all()
    |> then(&PageExclusions.new(section_id, page_resource_id, &1))
  end

  @doc """
  Returns selection-level exclusion state for trusted internal callers.
  """
  def get_selection_exclusion_view(section_or_id, page_resource_id, selection_id) do
    view = get_page_exclusion_view(section_or_id, page_resource_id)

    %{
      section_id: view.section_id,
      page_resource_id: view.page_resource_id,
      selection_id: selection_id,
      selection_enabled?: bank_selection_enabled?(view, selection_id),
      excluded_candidate_ids:
        Map.get(view.excluded_bank_candidate_ids_by_selection, selection_id, MapSet.new())
    }
  end

  @doc """
  Returns candidate review state for callers that already authorized access.

  Callers that already resolved the page revision and selection for the current
  preview session can pass `%Section{}`, `%Revision{}`, and the selection map
  directly to avoid repeating target-resolution queries. The response includes
  both candidate rows and lightweight paging/count metadata so preview surfaces
  can append additional pages without recomputing selection state locally.
  """
  @spec list_bank_selection_candidates(
          %Section{} | integer(),
          %Revision{} | integer(),
          map() | String.t(),
          keyword()
        ) ::
          {:ok, map()} | {:error, term()}
  def list_bank_selection_candidates(section_or_id, page_resource_id, selection_id, opts \\ [])

  def list_bank_selection_candidates(
        %Section{} = section,
        %Revision{} = page_revision,
        %{"id" => selection_id, "count" => count} = selection,
        opts
      )
      when is_binary(selection_id) do
    page_resource_id = page_revision.resource_id

    with {:ok, paging} <- normalize_candidate_paging(opts),
         {:ok, result} <-
           TargetResolver.list_candidates(section, page_revision, selection, paging) do
      exclusion_view = get_selection_exclusion_view(section, page_resource_id, selection_id)

      with {:ok, active_count} <-
             TargetResolver.count_active_candidates(
               section,
               page_revision,
               selection,
               exclusion_view.excluded_candidate_ids
             ) do
        {:ok,
         %{
           selection_id: selection_id,
           count: count,
           selection_enabled?: exclusion_view.selection_enabled?,
           active_count: active_count,
           total_count: result.totalCount,
           offset: paging.offset,
           limit: paging.limit,
           has_more?: paging.offset + result.rowCount < result.totalCount,
           candidates:
             Enum.map(result.rows, fn candidate ->
               enabled? =
                 !MapSet.member?(exclusion_view.excluded_candidate_ids, candidate.resource_id)

               %{
                 activity_resource_id: candidate.resource_id,
                 revision_slug: candidate.slug,
                 title: candidate.title,
                 enabled?: enabled?,
                 disable_allowed?: !enabled? or active_count > count
               }
             end)
         }}
      end
    end
  end

  def list_bank_selection_candidates(section_or_id, page_resource_id, selection_id, opts)
      when is_integer(page_resource_id) and is_binary(selection_id) do
    with {:ok, section, page_revision, selection} <-
           resolve_selection_target(section_or_id, page_resource_id, selection_id) do
      list_bank_selection_candidates(section, page_revision, selection, opts)
    end
  end

  @doc """
  Returns every activity type id currently matched by a resolved bank selection.

  Preview surfaces can use this to preload the scripts needed by the whole
  selection once, instead of recalculating script deltas as more candidate rows
  are paged in.
  """
  @spec list_bank_selection_candidate_activity_type_ids(
          %Section{},
          %Revision{},
          map(),
          non_neg_integer()
        ) :: {:ok, [integer()]} | {:error, term()}
  def list_bank_selection_candidate_activity_type_ids(
        %Section{} = section,
        %Revision{} = page_revision,
        selection,
        total_count
      )
      when is_integer(total_count) and total_count >= 0 do
    TargetResolver.list_candidate_activity_type_ids(
      section,
      page_revision,
      selection,
      total_count
    )
  end

  @doc """
  Returns selection-level candidate summary state for callers that do not need a
  paged candidate list.
  """
  def get_bank_selection_summary(section_or_id, page_resource_id, selection_id) do
    with {:ok, section, page_revision, selection} <-
           resolve_selection_target(section_or_id, page_resource_id, selection_id) do
      exclusion_view = get_selection_exclusion_view(section, page_resource_id, selection_id)

      with {:ok, active_count} <-
             TargetResolver.count_active_candidates(
               section,
               page_revision,
               selection,
               exclusion_view.excluded_candidate_ids
             ),
           {:ok, sample_candidate} <-
             TargetResolver.sample_candidate(
               section,
               page_revision,
               selection,
               exclusion_view.excluded_candidate_ids
             ) do
        {:ok,
         %{
           selection_id: selection_id,
           count: selection["count"],
           active_count: active_count,
           selection_enabled?: exclusion_view.selection_enabled?,
           sample_candidate: summarize_bank_candidate(sample_candidate, true, true)
         }}
      end
    end
  end

  @doc """
  Returns one random active candidate matching a page bank selection.
  """
  def sample_bank_selection_candidate(section_or_id, page_resource_id, selection_id) do
    with {:ok, section, page_revision, selection} <-
           resolve_selection_target(section_or_id, page_resource_id, selection_id) do
      exclusion_view = get_selection_exclusion_view(section, page_resource_id, selection_id)

      with {:ok, candidate} <-
             TargetResolver.sample_candidate(
               section,
               page_revision,
               selection,
               exclusion_view.excluded_candidate_ids
             ) do
        {:ok, summarize_bank_candidate(candidate, true, true)}
      end
    end
  end

  # Target validation

  @doc """
  Resolves the preview-route target for one bank selection on one page revision slug.

  This is the public preview-route boundary used by LiveViews and controllers.
  It keeps route-level section/page/selection lookup behind the
  `InstructorCustomizations` context instead of exposing `TargetResolver`
  directly to web callers.
  """
  @spec resolve_bank_selection_preview_target(%Section{} | integer(), String.t(), String.t()) ::
          {:ok, %Revision{}, map()} | {:error, term()}
  def resolve_bank_selection_preview_target(section_or_id, revision_slug, selection_id)
      when is_binary(revision_slug) and is_binary(selection_id) do
    with {:ok, section} <- TargetResolver.resolve_section(section_or_id) do
      TargetResolver.resolve_bank_selection_preview_target(section, revision_slug, selection_id)
    end
  end

  @doc """
  Validates that an embedded activity target belongs to the section page.
  """
  def validate_activity_customization_target(
        section_or_id,
        page_resource_id,
        activity_resource_id
      ) do
    with {:ok, _section, page_revision} <- resolve_page_target(section_or_id, page_resource_id),
         :ok <-
           TargetResolver.validate_embedded_activity_reference(
             page_revision,
             activity_resource_id
           ) do
      :ok
    end
  end

  @doc """
  Validates that a bank selection target belongs to the section page.
  """
  def validate_bank_selection_customization_target(section_or_id, page_resource_id, selection_id) do
    with {:ok, _section, _page_revision, _selection} <-
           resolve_selection_target(section_or_id, page_resource_id, selection_id) do
      :ok
    end
  end

  @doc """
  Validates that a bank candidate target currently matches a page selection.
  """
  def validate_bank_candidate_customization_target(
        section_or_id,
        page_resource_id,
        selection_id,
        candidate_activity_resource_id
      ) do
    with {:ok, section, page_revision, selection} <-
           resolve_selection_target(section_or_id, page_resource_id, selection_id),
         {:ok, true} <-
           TargetResolver.candidate_matches?(
             section,
             page_revision,
             selection,
             candidate_activity_resource_id
           ) do
      :ok
    else
      {:ok, false} -> {:error, {:invalid_selection_candidate, candidate_activity_resource_id}}
      error -> error
    end
  end

  # Writes

  @doc """
  Enables or disables an embedded activity for a section page.
  """
  def set_activity_enabled(
        section_or_id,
        page_resource_id,
        activity_resource_id,
        enabled,
        opts \\ []
      )
      when is_boolean(enabled) do
    attrs = %{kind: :embedded_activity, excluded_resource_id: activity_resource_id}

    set_enabled(
      section_or_id,
      page_resource_id,
      enabled,
      attrs,
      opts,
      &validate_activity_customization_target(&1, page_resource_id, activity_resource_id)
    )
  end

  @doc """
  Disables an embedded activity for a section page.
  """
  def exclude_activity(section_or_id, page_resource_id, activity_resource_id, opts \\ []) do
    set_activity_enabled(section_or_id, page_resource_id, activity_resource_id, false, opts)
  end

  @doc """
  Re-enables an embedded activity for a section page.
  """
  def restore_activity(section_or_id, page_resource_id, activity_resource_id, opts \\ []) do
    set_activity_enabled(section_or_id, page_resource_id, activity_resource_id, true, opts)
  end

  @doc """
  Enables or disables a whole activity bank selection for a section page.
  """
  def set_bank_selection_enabled(
        section_or_id,
        page_resource_id,
        selection_id,
        enabled,
        opts \\ []
      )
      when is_boolean(enabled) do
    attrs = %{kind: :bank_selection, selection_id: selection_id}

    set_enabled(
      section_or_id,
      page_resource_id,
      enabled,
      attrs,
      opts,
      &validate_bank_selection_customization_target(&1, page_resource_id, selection_id)
    )
  end

  @doc """
  Disables a whole activity bank selection for a section page.
  """
  def exclude_bank_selection(section_or_id, page_resource_id, selection_id, opts \\ []) do
    set_bank_selection_enabled(section_or_id, page_resource_id, selection_id, false, opts)
  end

  @doc """
  Re-enables a whole activity bank selection for a section page.
  """
  def restore_bank_selection(section_or_id, page_resource_id, selection_id, opts \\ []) do
    set_bank_selection_enabled(section_or_id, page_resource_id, selection_id, true, opts)
  end

  @doc """
  Disables one candidate within an activity bank selection.
  """
  def exclude_bank_candidate(
        section_or_id,
        page_resource_id,
        selection_id,
        candidate_activity_resource_id,
        opts \\ []
      ) do
    set_bank_candidate_enabled(
      section_or_id,
      page_resource_id,
      selection_id,
      candidate_activity_resource_id,
      false,
      opts
    )
  end

  @doc """
  Re-enables one candidate within an activity bank selection.
  """
  def restore_bank_candidate(
        section_or_id,
        page_resource_id,
        selection_id,
        candidate_activity_resource_id,
        opts \\ []
      ) do
    set_bank_candidate_enabled(
      section_or_id,
      page_resource_id,
      selection_id,
      candidate_activity_resource_id,
      true,
      opts
    )
  end

  @doc """
  Enables or disables one candidate within an activity bank selection.
  """
  def set_bank_candidate_enabled(
        section_or_id,
        page_resource_id,
        selection_id,
        candidate_activity_resource_id,
        enabled,
        opts \\ []
      )
      when is_boolean(enabled) do
    with {:ok, section} <- TargetResolver.resolve_section(section_or_id),
         :ok <- authorize_write(section, opts) do
      if enabled do
        restore_candidate(section, page_resource_id, selection_id, candidate_activity_resource_id)
      else
        exclude_candidate(section, page_resource_id, selection_id, candidate_activity_resource_id)
      end
    end
  end

  # Predicates

  @doc """
  Returns whether an embedded activity is enabled in a page exclusion view.
  """
  def activity_enabled?(%PageExclusions{} = exclusions, activity_resource_id) do
    !MapSet.member?(exclusions.excluded_activity_ids, activity_resource_id)
  end

  @doc """
  Returns whether a whole bank selection is enabled in a page exclusion view.
  """
  def bank_selection_enabled?(%PageExclusions{} = exclusions, selection_id) do
    !MapSet.member?(exclusions.excluded_selection_ids, selection_id)
  end

  @doc """
  Returns whether a bank candidate is enabled in a page exclusion view.
  """
  def bank_candidate_enabled?(%PageExclusions{} = exclusions, selection_id, activity_resource_id) do
    case Map.fetch(exclusions.excluded_bank_candidate_ids_by_selection, selection_id) do
      {:ok, excluded_candidate_ids} ->
        !MapSet.member?(excluded_candidate_ids, activity_resource_id)

      :error ->
        true
    end
  end

  # Shared persistence

  defp set_enabled(section_or_id, page_resource_id, enabled, attrs, opts, validate_target) do
    with {:ok, section} <- TargetResolver.resolve_section(section_or_id),
         :ok <- authorize_write(section, opts),
         :ok <- validate_target.(section),
         :ok <- persist_enabled(section.id, page_resource_id, enabled, attrs) do
      {:ok, get_page_exclusion_view(section.id, page_resource_id)}
    end
  end

  defp persist_enabled(section_id, page_resource_id, false, attrs) do
    %ActivityExclusion{}
    |> ActivityExclusion.changeset(section_id, page_resource_id, attrs)
    |> Repo.insert(on_conflict: :nothing)
    |> case do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, {:validation_failed, changeset}}
    end
  end

  defp persist_enabled(section_id, page_resource_id, true, attrs) do
    ActivityExclusion
    |> where([exclusion], exclusion.section_id == ^section_id)
    |> where([exclusion], exclusion.page_resource_id == ^page_resource_id)
    |> where([exclusion], exclusion.kind == ^attrs.kind)
    |> target_where(attrs)
    |> Repo.delete_all()

    :ok
  end

  defp target_where(query, %{kind: :embedded_activity, excluded_resource_id: resource_id}) do
    where(query, [exclusion], exclusion.excluded_resource_id == ^resource_id)
  end

  defp target_where(query, %{kind: :bank_selection, selection_id: selection_id}) do
    where(query, [exclusion], exclusion.selection_id == ^selection_id)
  end

  defp target_where(query, %{
         kind: :bank_candidate,
         selection_id: selection_id,
         excluded_resource_id: resource_id
       }) do
    where(
      query,
      [exclusion],
      exclusion.selection_id == ^selection_id and exclusion.excluded_resource_id == ^resource_id
    )
  end

  # Candidate writes

  defp exclude_candidate(section, page_resource_id, selection_id, candidate_activity_resource_id) do
    attrs = candidate_exclusion_attrs(selection_id, candidate_activity_resource_id)

    Repo.transaction(fn ->
      do_exclude_candidate(
        section,
        page_resource_id,
        selection_id,
        candidate_activity_resource_id,
        attrs
      )
    end)
  end

  defp restore_candidate(section, page_resource_id, selection_id, candidate_activity_resource_id) do
    attrs = candidate_exclusion_attrs(selection_id, candidate_activity_resource_id)

    with {:ok, _section, _page_revision, _selection} <-
           resolve_selection_target(section, page_resource_id, selection_id),
         :ok <- persist_enabled(section.id, page_resource_id, true, attrs) do
      {:ok, get_page_exclusion_view(section.id, page_resource_id)}
    end
  end

  defp validate_candidate_disable(
         section,
         page_revision,
         selection,
         candidate_activity_resource_id
       ) do
    excluded_ids =
      get_selection_exclusion_view(section.id, page_revision.resource_id, selection["id"])
      |> Map.fetch!(:excluded_candidate_ids)

    with {:ok, true} <-
           TargetResolver.candidate_matches?(
             section,
             page_revision,
             selection,
             candidate_activity_resource_id
           ),
         {:ok, active_count} <-
           TargetResolver.count_active_candidates(
             section,
             page_revision,
             selection,
             MapSet.put(excluded_ids, candidate_activity_resource_id)
           ) do
      if active_count >= selection["count"] do
        :ok
      else
        {:error,
         {:insufficient_selection_candidates,
          %{
            selection_id: selection["id"],
            count: selection["count"],
            active_candidates: active_count
          }}}
      end
    else
      {:ok, false} -> {:error, {:invalid_selection_candidate, candidate_activity_resource_id}}
      error -> error
    end
  end

  defp normalize_candidate_paging(opts) do
    offset = Keyword.get(opts, :offset, 0)
    limit = Keyword.get(opts, :limit, @default_candidate_limit)

    case {offset, limit} do
      {offset, limit}
      when is_integer(offset) and offset >= 0 and is_integer(limit) and limit > 0 ->
        {:ok, %Paging{offset: offset, limit: limit}}

      {offset, _limit} when not is_integer(offset) or offset < 0 ->
        {:error, {:invalid_paging, :offset}}

      _ ->
        {:error, {:invalid_paging, :limit}}
    end
  end

  defp summarize_bank_candidate(nil, _enabled?, _disable_allowed?), do: nil

  defp summarize_bank_candidate(candidate, enabled?, disable_allowed?) do
    %{
      activity_resource_id: candidate.resource_id,
      revision_slug: candidate.slug,
      title: candidate.title,
      enabled?: enabled?,
      disable_allowed?: disable_allowed?
    }
  end

  defp exclusion_exists?(section_id, page_resource_id, attrs) do
    ActivityExclusion
    |> where([exclusion], exclusion.section_id == ^section_id)
    |> where([exclusion], exclusion.page_resource_id == ^page_resource_id)
    |> where([exclusion], exclusion.kind == ^attrs.kind)
    |> target_where(attrs)
    |> Repo.exists?()
  end

  defp candidate_exclusion_attrs(selection_id, candidate_activity_resource_id) do
    %{
      kind: :bank_candidate,
      selection_id: selection_id,
      excluded_resource_id: candidate_activity_resource_id
    }
  end

  defp do_exclude_candidate(
         section,
         page_resource_id,
         selection_id,
         candidate_activity_resource_id,
         attrs
       ) do
    with :ok <- lock_page(section.id, page_resource_id),
         {:exists?, false} <-
           {:exists?, exclusion_exists?(section.id, page_resource_id, attrs)},
         {:ok, _section, page_revision, selection} <-
           resolve_selection_target(section, page_resource_id, selection_id),
         :ok <-
           validate_candidate_disable(
             section,
             page_revision,
             selection,
             candidate_activity_resource_id
           ),
         :ok <- persist_enabled(section.id, page_resource_id, false, attrs) do
      get_page_exclusion_view(section.id, page_resource_id)
    else
      {:exists?, true} ->
        get_page_exclusion_view(section.id, page_resource_id)

      {:error, reason} ->
        Repo.rollback(reason)
    end
  end

  defp lock_page(section_id, page_resource_id) do
    # This SELECT does not update SectionResource. The FOR UPDATE row lock uses
    # the section/page row as a transaction-scoped mutex for candidate count
    # checks. PostgreSQL releases it automatically on commit or rollback.
    case Repo.one(
           from(section_resource in SectionResource,
             where:
               section_resource.section_id == ^section_id and
                 section_resource.resource_id == ^page_resource_id,
             lock: "FOR UPDATE"
           )
         ) do
      nil -> {:error, {:not_found, :page}}
      _ -> :ok
    end
  end

  # Target resolution and authorization

  defp resolve_page_target(section_or_id, page_resource_id) do
    with {:ok, section} <- TargetResolver.resolve_section(section_or_id),
         {:ok, page_revision} <- TargetResolver.resolve_page(section, page_resource_id) do
      {:ok, section, page_revision}
    end
  end

  defp resolve_selection_target(section_or_id, page_resource_id, selection_id) do
    with {:ok, section, page_revision} <- resolve_page_target(section_or_id, page_resource_id),
         {:ok, selection} <- TargetResolver.resolve_selection(page_revision, selection_id) do
      {:ok, section, page_revision, selection}
    end
  end

  defp authorize_write(section, opts) do
    case Keyword.get(opts, :actor) do
      %User{} = user ->
        user = Repo.preload(user, :platform_roles)

        if Sections.is_instructor?(user, section.slug) or Sections.is_admin?(user, section.slug) do
          :ok
        else
          {:error, {:unauthorized, :customize_section}}
        end

      %Author{} = author ->
        if Accounts.at_least_content_admin?(author) do
          :ok
        else
          {:error, {:unauthorized, :customize_section}}
        end

      _ ->
        {:error, {:unauthorized, :customize_section}}
    end
  end

  defp section_id(%Section{id: id}), do: id
  defp section_id(id) when is_integer(id), do: id
end
