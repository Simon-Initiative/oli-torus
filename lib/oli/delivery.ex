defmodule Oli.Delivery do
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Settings.StudentException
  alias Oli.Delivery.Sections.{Section, SectionsProjectsPublications}
  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Repo
  alias Oli.Publishing.{DeliveryResolver, PublishedResource}
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, ActivityAttempt, ResourceAccess}
  alias Oli.Delivery.ResearchConsent
  alias Oli.Accounts.User

  import Ecto.Query, warn: false
  import Oli.Utils

  @doc """
  Returns true if the user is required to provide research consent.

  When a section is provided and it is associated with an institution, that
  institution's research consent setting is authoritative. Otherwise the
  decision falls back to the user-level behavior: the global platform setting
  for direct delivery users, and the user's institution for LTI users.
  """
  def user_research_consent_required?(user, section \\ nil)

  def user_research_consent_required?(nil, _section), do: false

  def user_research_consent_required?(user, %Section{institution_id: institution_id})
      when not is_nil(institution_id) do
    case research_consent_for_institution(institution_id) do
      nil -> user_research_consent_required?(user, nil)
      research_consent -> research_consent_required?(research_consent)
    end
  end

  def user_research_consent_required?(%User{independent_learner: true}, _section) do
    # Direct delivery users with no section institution fall back to the platform setting
    research_consent_required?(get_system_research_consent_form_setting())
  end

  def user_research_consent_required?(user, _section) do
    # LTI users
    case Institutions.get_institution_by_lti_user(user) do
      %Institution{research_consent: research_consent} ->
        research_consent_required?(research_consent)

      _ ->
        false
    end
  end

  @doc """
  Returns true if research consent is required for the section identified by the
  given return-to slug, resolving the section's institution setting in a single
  query.

  Falls back to the user-level policy when the slug is nil, unknown, or the
  section has no associated institution.
  """
  def user_research_consent_required_for_slug?(nil, _slug), do: false

  def user_research_consent_required_for_slug?(user, nil),
    do: user_research_consent_required?(user, nil)

  def user_research_consent_required_for_slug?(user, slug) do
    case Sections.get_section_research_consent_by_slug(slug) do
      {institution_id, research_consent} when not is_nil(institution_id) ->
        research_consent_required?(research_consent)

      _ ->
        user_research_consent_required?(user, nil)
    end
  end

  defp research_consent_for_institution(institution_id) do
    Repo.one(from(i in Institution, where: i.id == ^institution_id, select: i.research_consent))
  end

  defp research_consent_required?(:oli_form), do: true
  defp research_consent_required?(_), do: false

  # ------------------------------------------------------------
  # Delivery Settings

  @doc """
  Returns the list of delivery settings that meets the criteria passed in the filter.

  ## Examples

      iex> search_delivery_settings(%{section_id: 1, resource_id: 1})
      [%Post{section_id: 1, resource_id: 1}, ...]

      iex> search_delivery_settings(%{resource_id: 123})
      []
  """
  def search_delivery_settings(filter) do
    from(ds in StudentException, where: ^filter_conditions(filter))
    |> Repo.all()
  end

  @spec create_delivery_setting(
          :invalid
          | %{optional(:__struct__) => none, optional(atom | binary) => any}
        ) :: any
  @doc """
  Creates a delivery setting.

  ## Examples

      iex> create_delivery_setting(%{field: new_value})
      {:ok, %StudentException{}}

      iex> create_delivery_setting(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_delivery_setting(attrs \\ %{}) do
    %StudentException{}
    |> StudentException.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a delivery setting that meets the criteria passed in the clauses.

  ## Examples

      iex> get_delivery_setting_by(%{id: 1})
      %StudentException{}

      iex> get_delivery_setting_by(%{id: 123})
      nil
  """
  def get_delivery_setting_by(clauses),
    do: Repo.get_by(StudentException, clauses)

  @doc """
  Updates a delivery setting.

  ## Examples

      iex> update_delivery_setting(delivery_setting, %{field: new_value})
      {:ok, %StudentException{}}

      iex> update_delivery_setting(delivery_setting, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_delivery_setting(%StudentException{} = delivery_setting, attrs) do
    delivery_setting
    |> StudentException.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking delivery setting changes.

  ## Examples

      iex> change_delivery_setting(delivery_setting)
      %Ecto.Changeset{data: %StudentException{}}
  """
  def change_delivery_setting(%StudentException{} = delivery_setting, attrs \\ %{}) do
    StudentException.changeset(delivery_setting, attrs)
  end

  @doc """
  Creates a new, or updates the existing delivery setting
  for the given section and resource.

  ## Examples

      iex> upsert_delivery_setting(%{field: new_value})
      {:ok, %StudentException{}}

      iex> upsert_delivery_setting(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def upsert_delivery_setting(attrs) do
    section_id = attrs["section_id"] || attrs.section_id
    resource_id = attrs["resource_id"] || attrs.resource_id

    case get_delivery_setting_by(%{
           section_id: section_id,
           resource_id: resource_id
         }) do
      nil -> create_delivery_setting(attrs)
      ds -> update_delivery_setting(ds, attrs)
    end
  end

  defp contains_explorations(section_slug) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    Repo.one(
      from([sr: sr, rev: rev] in DeliveryResolver.section_resource_revisions(section_slug),
        where:
          rev.purpose == :application and rev.deleted == false and
            rev.resource_type_id == ^page_id,
        select: rev.id,
        limit: 1
      )
    )
    |> case do
      nil -> false
      _ -> true
    end
  end

  defp update_contains_explorations(section, value) do
    section
    |> Section.changeset(%{contains_explorations: value})
    |> Repo.update()
  end

  def maybe_update_section_contains_explorations(
        %Section{
          slug: section_slug,
          contains_explorations: contains_explorations
        } = section
      ) do
    case {contains_explorations(section_slug), contains_explorations} do
      {true, false} ->
        update_contains_explorations(section, true)

      {false, true} ->
        update_contains_explorations(section, false)

      _ ->
        {:ok, section}
    end
  end

  defp contains_deliberate_practice(section_slug) do
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")

    Repo.one(
      from([sr: sr, rev: rev] in DeliveryResolver.section_resource_revisions(section_slug),
        where:
          rev.purpose == :deliberate_practice and rev.deleted == false and
            rev.resource_type_id == ^page_id,
        select: rev.id,
        limit: 1
      )
    )
    |> case do
      nil -> false
      _ -> true
    end
  end

  defp update_contains_deliberate_practice(section, value) do
    section
    |> Section.changeset(%{contains_deliberate_practice: value})
    |> Repo.update()
  end

  def maybe_update_section_contains_deliberate_practice(
        %Section{
          slug: section_slug,
          contains_deliberate_practice: contains_deliberate_practice
        } = section
      ) do
    case {contains_deliberate_practice(section_slug), contains_deliberate_practice} do
      {true, false} ->
        update_contains_deliberate_practice(section, true)

      {false, true} ->
        update_contains_deliberate_practice(section, false)

      _ ->
        {:ok, section}
    end
  end

  defp survey_resource_access(section_slug, user_id) do
    ResourceAccess
    |> join(:inner, [r], s in Section,
      on: r.section_id == s.id and r.resource_id == s.required_survey_resource_id
    )
    |> where(
      [r, s],
      r.section_id == s.id and r.user_id == ^user_id and s.slug == ^section_slug
    )
    |> select([r, s], %{
      resource_access_id: r.id,
      section_id: r.section_id,
      project_id: s.base_project_id
    })
    |> Repo.one()
  end

  def has_completed_survey?(section_slug, user_id) do
    case survey_resource_access(section_slug, user_id) do
      nil ->
        false

      %{
        section_id: section_id,
        project_id: project_id,
        resource_access_id: resource_access_id
      } ->
        SectionsProjectsPublications
        |> join(:inner, [spp], pr in PublishedResource,
          on: pr.publication_id == spp.publication_id
        )
        |> join(:inner, [_spp, pr], a_att in ActivityAttempt,
          on: a_att.revision_id == pr.revision_id
        )
        |> join(:inner, [_spp, _pr, a_att], r_att in ResourceAttempt,
          on: r_att.id == a_att.resource_attempt_id
        )
        |> join(:left, [_spp, _pr, _a_att, r_att], r_att_2 in ResourceAttempt,
          on: r_att_2.resource_access_id == r_att.resource_access_id and r_att.id < r_att_2.id
        )
        |> where(
          [spp, _pr, _a_att, r_att, r_att_2],
          spp.section_id == ^section_id and
            spp.project_id == ^project_id and
            r_att.resource_access_id == ^resource_access_id and
            is_nil(r_att_2)
        )
        |> group_by([_spp, _pr, a_att], [a_att.revision_id, a_att.lifecycle_state])
        |> select(
          [_spp, _pr, a_att, _r_att, _r_acc],
          {a_att.revision_id, a_att.lifecycle_state}
        )
        |> Repo.all()
        |> Enum.reduce(%{}, fn {revision_id, lifecycle_state}, acc ->
          if Map.get(acc, revision_id) == :evaluated do
            acc
          else
            Map.put(acc, revision_id, lifecycle_state)
          end
        end)
        |> Enum.all?(&(elem(&1, 1) == :evaluated))
    end
  end

  @doc """
  Returns the research consent form setting.

  This record is created during migration so a single record is always expected to exist.
  """
  def get_system_research_consent_form_setting() do
    Repo.one(ResearchConsent)
    |> Map.get(:research_consent)
  end
end
