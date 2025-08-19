defmodule Oli.Delivery do
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.PostProcessing
  alias Oli.Delivery.Settings.StudentException
  alias Oli.Delivery.Sections.{Section, SectionsProjectsPublications, SectionSpecification}
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
  Creates a new section from the given changeset and source identifier. Depending on the
  section specification provided, the section will either be created as a direct delivery section
  or an LTI section with the appropriate settings.

  A section can be created from a project, publication or product (blueprint) depending on the
  source identifier. The source identifier is expected to be in the format:
    - `project:<project_id>` for a project
    - `publication:<publication_id>` for a publication
    - `product:<product_id>` for a product

  The return value is one of the following:
    - `{:ok, section.id, section.slug}`: The section was successfully created.
    - `{:error, error_msg}`: An error occurred while creating the section.

  Examples:
    iex> create_section(changeset, "project:1", user, section_spec)
    {:ok, 1, "section-slug"}

    iex> create_section(changeset, "publication:1", user, section_spec)
    {:ok, 1, "section-slug"}
    {:error, "Failed to create new section"}

  """
  def create_section(changeset, source, user, section_spec) do
    # Check if section already exists for LTI specifications
    case section_spec do
      %SectionSpecification.Lti{lti_params: lti_params} ->
        case Sections.get_section_from_lti_params(lti_params) do
          nil -> create_new_section(changeset, source, user, section_spec)
          existing_section -> {:ok, existing_section.id, existing_section.slug}
        end

      _ ->
        create_new_section(changeset, source, user, section_spec)
    end
  end

  defp create_new_section(changeset, source, user, section_spec) do
    case from_source_identifier(source) do
      {:project, project} ->
        %{id: project_id, has_experiments: has_experiments} =
          Oli.Authoring.Course.get_project_by_slug(project.slug)

        publication =
          Oli.Publishing.get_latest_published_publication_by_slug(project.slug)
          |> Repo.preload(:project)

        customizations =
          case publication.project.customizations do
            nil -> nil
            labels -> Map.from_struct(labels)
          end

        section_params =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Map.from_struct()
          |> Map.merge(%{
            type: :enrollable,
            base_project_id: project_id,
            context_id: UUID.uuid4(),
            customizations: customizations,
            has_experiments: has_experiments,
            analytics_version: :v2,
            welcome_title: project.welcome_title,
            encouraging_subtitle: project.encouraging_subtitle,
            certificate: nil
          })
          |> SectionSpecification.apply(section_spec)

        case create_from_publication(user, publication, section_params) do
          {:ok, section} ->
            {:ok, section.id, section.slug}

          {:error, error} ->
            {_error_id, error_msg} = log_error("Failed to create new section", error)
            {:error, error_msg}
        end

      {:product, blueprint} ->
        project = Oli.Repo.get(Oli.Authoring.Course.Project, blueprint.base_project_id)

        # Try to calculate the cost from the product. If that fails, use the blueprint amount
        amount =
          case Oli.Delivery.Paywall.section_cost_from_product(
                 blueprint,
                 SectionSpecification.get_institution(section_spec)
               ) do
            {:ok, amount} -> amount
            _ -> blueprint.amount
          end

        section_params =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Map.from_struct()
          |> Map.take([
            :title,
            :course_section_number,
            :class_modality,
            :class_days,
            :start_date,
            :end_date,
            :preferred_scheduling_time
          ])
          |> Map.merge(%{
            blueprint_id: blueprint.id,
            required_survey_resource_id: project.required_survey_resource_id,
            type: :enrollable,
            has_experiments: project.has_experiments,
            context_id: UUID.uuid4(),
            analytics_version: :v2,
            welcome_title: blueprint.welcome_title,
            encouraging_subtitle: blueprint.encouraging_subtitle,
            amount: amount
          })
          |> SectionSpecification.apply(section_spec)

        case create_from_product(user, blueprint, section_params) do
          {:ok, section} ->
            {:ok, section.id, section.slug}

          {:error, error} ->
            {_error_id, error_msg} = log_error("Failed to create new section", error)

            {:error, error_msg}
        end
    end
  end

  defp create_from_publication(user, publication, section_params) do
    Repo.transaction(fn ->
      with {:ok, section} <- Sections.create_section(section_params),
           {:ok, section} <- Sections.create_section_resources(section, publication),
           {:ok, _} <- Sections.rebuild_contained_pages(section),
           {:ok, _} <- Sections.rebuild_contained_objectives(section),
           {:ok, _enrollment} <-
             Sections.enroll(user.id, section.id, [
               ContextRoles.get_role(:context_instructor)
             ]) do
        # Log the section creation
        Oli.Auditing.capture(
          user,
          :section_created,
          section,
          %{
            "section_title" => section.title,
            "type" => Atom.to_string(section.type),
            "base_project_id" => section.base_project_id
          }
        )
        
        PostProcessing.apply(section, :all)
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp create_from_product(user, blueprint, section_params) do
    Repo.transaction(fn ->
      with {:ok, section} <- Oli.Delivery.Sections.Blueprint.duplicate(blueprint, section_params),
           {:ok, _} <- Sections.rebuild_contained_pages(section),
           {:ok, _} <- Sections.rebuild_contained_objectives(section),
           {:ok, _maybe_enrollment} <-
             Sections.enroll(user.id, section.id, [
               ContextRoles.get_role(:context_instructor)
             ]) do
        # Log the section creation
        Oli.Auditing.capture(
          user,
          :section_created,
          section,
          %{
            "section_title" => section.title,
            "type" => Atom.to_string(section.type),
            "base_project_id" => section.base_project_id,
            "blueprint_id" => blueprint.id
          }
        )
        
        PostProcessing.apply(section, :discussions)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  # Returns a product or project used to create the section based on the source identifier.
  defp from_source_identifier(source_id) do
    case source_id do
      "product:" <> id ->
        {:product, Sections.get_section!(String.to_integer(id))}

      "publication:" <> id ->
        publication =
          Oli.Publishing.get_publication!(String.to_integer(id)) |> Repo.preload(:project)

        {:project, publication.project}

      "project:" <> id ->
        project = Oli.Authoring.Course.get_project!(id)

        {:project, project}
    end
  end

  @doc """
  Returns true if the user is required to provide research consent
  """
  def user_research_consent_required?(nil), do: false

  def user_research_consent_required?(%User{independent_learner: true}) do
    # Direct delivery users
    case get_system_research_consent_form_setting() do
      :oli_form -> true
      _ -> false
    end
  end

  def user_research_consent_required?(user) do
    # LTI users
    case Institutions.get_institution_by_lti_user(user) do
      %Institution{research_consent: :oli_form} -> true
      _ -> false
    end
  end

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

  @doc """
  Updates the research consent form setting.
  """
  def update_system_research_consent_form_setting(research_consent) do
    case Repo.one(ResearchConsent) do
      nil ->
        Repo.insert!(%ResearchConsent{research_consent: research_consent})

      %ResearchConsent{} = research_consent_form ->
        research_consent_form
        |> ResearchConsent.changeset(%{research_consent: research_consent})
        |> Repo.update()
    end
  end
end
