defmodule Oli.Experiments.ScopeValidator do
  @moduledoc """
  Resolves and authorizes experiment scopes against their persisted tenancy relationships.

  This module is an internal boundary used by `Oli.Experiments`; callers should use
  the context API rather than invoking it directly.
  """

  import Ecto.Query

  alias Oli.Accounts.User
  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.{Enrollment, Section, SectionsProjectsPublications}
  alias Oli.Experiments.{ExperimentError, Scope}
  alias Oli.Experiments.Schemas.{ExperimentDefinition, ExperimentSection}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo

  @doc false
  def require_authoring_access(scope) do
    with :ok <- require_authoring_scope(scope),
         :ok <- require_eligible_section_reader(scope) do
      :ok
    end
  end

  @doc false
  def require_authoring_scope(%Scope{enrollment_id: nil}), do: :ok

  def require_authoring_scope(_scope) do
    invalid_scope("authoring experiments must be project- or section-scoped")
  end

  @doc false
  def require_eligible_section_reader(%Scope{
        author_id: author_id,
        project_id: project_id
      })
      when not is_nil(author_id) do
    author = Repo.get(Oli.Accounts.Author, author_id)

    accepted_collaborator? =
      Repo.exists?(
        from(author_project in AuthorProject,
          where:
            author_project.author_id == ^author_id and
              author_project.project_id == ^project_id and
              author_project.status == :accepted
        )
      )

    case accepted_collaborator? or Oli.Accounts.is_admin?(author) do
      true -> :ok
      false -> invalid_scope("author cannot access project sections")
    end
  end

  def require_eligible_section_reader(_scope) do
    invalid_scope("author scope is required")
  end

  @doc false
  def validate_scope(%Scope{} = scope) do
    with {:ok, scope} <- validate_institution(scope),
         {:ok, scope} <- validate_project(scope),
         {:ok, scope} <- validate_section(scope),
         {:ok, scope} <- validate_publication(scope),
         {:ok, scope} <- validate_user(scope),
         {:ok, scope} <- validate_enrollment(scope) do
      {:ok, scope}
    end
  end

  def validate_scope(_scope), do: invalid_scope("scope is required")

  @doc false
  def validate_delivery_participation_scope(
        %Scope{
          project_id: project_id,
          section_id: section_id,
          user_id: user_id,
          enrollment_id: enrollment_id
        } = scope
      )
      when is_integer(project_id) and is_integer(section_id) and is_integer(user_id) and
             is_integer(enrollment_id) do
    query =
      from(section in Section,
        as: :section,
        join: project in Project,
        on: project.id == ^project_id,
        join: user in User,
        on: user.id == ^user_id,
        join: enrollment in Enrollment,
        on:
          enrollment.id == ^enrollment_id and enrollment.section_id == section.id and
            enrollment.user_id == user.id,
        where: section.id == ^section_id,
        select:
          {section, project, user, enrollment,
           exists(
             from(spp in SectionsProjectsPublications,
               where: spp.section_id == parent_as(:section).id and spp.project_id == ^project_id
             )
           )}
      )

    case Repo.one(query) do
      {section, project, _user, _enrollment, project_relationship?} ->
        cond do
          not is_nil(scope.institution_id) and section.institution_id != scope.institution_id ->
            invalid_scope("section does not belong to institution", %{
              section_id: section.id,
              institution_id: scope.institution_id,
              actual_institution_id: section.institution_id
            })

          not is_nil(scope.project_slug) and project.slug != scope.project_slug ->
            invalid_scope("project slug does not match project_id", %{
              project_id: project.id,
              project_slug: scope.project_slug,
              actual_slug: project.slug
            })

          not is_nil(scope.section_slug) and section.slug != scope.section_slug ->
            invalid_scope("section slug does not match section_id", %{
              section_id: section.id,
              section_slug: scope.section_slug,
              actual_slug: section.slug
            })

          true ->
            {:ok,
             %{
               scope
               | project_slug: scope.project_slug || project.slug,
                 section_slug: scope.section_slug || section.slug,
                 project_relationship?: project_relationship?
             }}
        end

      nil ->
        invalid_scope("delivery participation scope is invalid")
    end
  end

  def validate_delivery_participation_scope(%Scope{} = scope) do
    with {:ok, scope} <- validate_institution(scope),
         {:ok, scope} <- validate_project(scope),
         {:ok, scope} <- validate_participation_section(scope),
         {:ok, scope} <- validate_user(scope),
         {:ok, scope} <- validate_enrollment(scope) do
      {:ok, scope}
    end
  end

  def validate_delivery_participation_scope(_scope), do: invalid_scope("scope is required")

  defp validate_institution(%Scope{institution_id: nil} = scope), do: {:ok, scope}

  defp validate_institution(%Scope{institution_id: institution_id} = scope) do
    case Repo.get(Oli.Institutions.Institution, institution_id) do
      nil -> invalid_scope("institution not found", %{institution_id: institution_id})
      _institution -> {:ok, scope}
    end
  end

  defp validate_project(%Scope{project_id: nil, project_slug: nil}) do
    invalid_scope("project_id or project_slug is required")
  end

  defp validate_project(%Scope{project_id: project_id} = scope) when not is_nil(project_id) do
    case Repo.get(Project, project_id) do
      nil ->
        invalid_scope("project not found", %{project_id: project_id})

      project ->
        validate_project_slug(
          %{scope | project_id: project.id, project_slug: scope.project_slug || project.slug},
          project
        )
    end
  end

  defp validate_project(%Scope{project_slug: project_slug} = scope) do
    case Repo.get_by(Project, slug: project_slug) do
      nil -> invalid_scope("project not found", %{project_slug: project_slug})
      project -> {:ok, %{scope | project_id: project.id, project_slug: project.slug}}
    end
  end

  defp validate_project_slug(%Scope{project_slug: nil} = scope, _project), do: {:ok, scope}

  defp validate_project_slug(%Scope{project_slug: project_slug} = scope, %Project{
         slug: project_slug
       }) do
    {:ok, scope}
  end

  defp validate_project_slug(%Scope{} = scope, %Project{} = project) do
    invalid_scope("project slug does not match project_id", %{
      project_id: scope.project_id,
      project_slug: scope.project_slug,
      actual_slug: project.slug
    })
  end

  @doc false
  def validate_publication(%Scope{publication_id: nil} = scope), do: {:ok, scope}

  def validate_publication(%Scope{publication_id: publication_id, project_id: project_id} = scope) do
    case Repo.get(Publication, publication_id) do
      nil ->
        invalid_scope("publication not found", %{publication_id: publication_id})

      %Publication{project_id: ^project_id} ->
        validate_section_publication(scope)

      %Publication{project_id: actual_project_id} ->
        invalid_scope("publication does not belong to project", %{
          publication_id: publication_id,
          project_id: project_id,
          actual_project_id: actual_project_id
        })
    end
  end

  defp validate_section_publication(%Scope{section_id: nil} = scope), do: {:ok, scope}

  defp validate_section_publication(%Scope{} = scope) do
    case Repo.exists?(
           from(spp in SectionsProjectsPublications,
             where:
               spp.section_id == ^scope.section_id and
                 spp.project_id == ^scope.project_id and
                 spp.publication_id == ^scope.publication_id
           )
         ) do
      true ->
        {:ok, scope}

      false ->
        invalid_scope("publication is not deployed to section", %{
          publication_id: scope.publication_id,
          project_id: scope.project_id,
          section_id: scope.section_id
        })
    end
  end

  defp validate_section(%Scope{section_id: nil, section_slug: nil} = scope), do: {:ok, scope}

  defp validate_section(%Scope{section_id: section_id} = scope) when not is_nil(section_id) do
    case Repo.get(Section, section_id) do
      nil ->
        invalid_scope("section not found", %{section_id: section_id})

      section ->
        validate_section_scope(
          %{scope | section_id: section.id, section_slug: scope.section_slug || section.slug},
          section
        )
    end
  end

  defp validate_section(%Scope{section_slug: section_slug} = scope) do
    case Repo.get_by(Section, slug: section_slug) do
      nil ->
        invalid_scope("section not found", %{section_slug: section_slug})

      section ->
        validate_section_scope(
          %{scope | section_id: section.id, section_slug: section.slug},
          section
        )
    end
  end

  defp validate_participation_section(%Scope{section_id: nil, section_slug: nil} = scope),
    do: {:ok, scope}

  defp validate_participation_section(%Scope{section_id: section_id} = scope)
       when not is_nil(section_id) do
    case participation_section(section_id, scope.project_id) do
      nil ->
        invalid_scope("section not found", %{section_id: section_id})

      {section, project_relationship?} ->
        validate_participation_section_scope(
          %{
            scope
            | section_id: section.id,
              section_slug: scope.section_slug || section.slug,
              project_relationship?: project_relationship?
          },
          section
        )
    end
  end

  defp validate_participation_section(%Scope{section_slug: section_slug} = scope) do
    case participation_section_by_slug(section_slug, scope.project_id) do
      nil ->
        invalid_scope("section not found", %{section_slug: section_slug})

      {section, project_relationship?} ->
        validate_participation_section_scope(
          %{
            scope
            | section_id: section.id,
              section_slug: section.slug,
              project_relationship?: project_relationship?
          },
          section
        )
    end
  end

  defp participation_section(section_id, project_id) do
    from(section in Section,
      as: :section,
      where: section.id == ^section_id,
      select:
        {section,
         exists(
           from(spp in SectionsProjectsPublications,
             where:
               spp.section_id == parent_as(:section).id and
                 spp.project_id == ^project_id
           )
         )}
    )
    |> Repo.one()
  end

  defp participation_section_by_slug(section_slug, project_id) do
    from(section in Section,
      as: :section,
      where: section.slug == ^section_slug,
      select:
        {section,
         exists(
           from(spp in SectionsProjectsPublications,
             where:
               spp.section_id == parent_as(:section).id and
                 spp.project_id == ^project_id
           )
         )}
    )
    |> Repo.one()
  end

  defp validate_participation_section_scope(scope, section) do
    cond do
      section.slug != scope.section_slug ->
        invalid_scope("section slug does not match section_id", %{
          section_id: scope.section_id,
          section_slug: scope.section_slug,
          actual_slug: section.slug
        })

      not is_nil(scope.institution_id) and not is_nil(section.institution_id) and
          section.institution_id != scope.institution_id ->
        invalid_scope("section does not belong to institution", %{
          section_id: section.id,
          institution_id: scope.institution_id,
          actual_institution_id: section.institution_id
        })

      true ->
        {:ok, scope}
    end
  end

  defp validate_section_scope(scope, section) do
    cond do
      not is_nil(scope.section_slug) and section.slug != scope.section_slug ->
        invalid_scope("section slug does not match section_id", %{
          section_id: scope.section_id,
          section_slug: scope.section_slug,
          actual_slug: section.slug
        })

      not is_nil(scope.institution_id) and not is_nil(section.institution_id) and
          section.institution_id != scope.institution_id ->
        invalid_scope("section does not belong to institution", %{
          section_id: section.id,
          institution_id: scope.institution_id,
          actual_institution_id: section.institution_id
        })

      section.base_project_id != scope.project_id ->
        invalid_scope("section does not belong to project", %{
          section_id: section.id,
          project_id: scope.project_id,
          actual_project_id: section.base_project_id
        })

      true ->
        {:ok, scope}
    end
  end

  defp validate_user(%Scope{user_id: nil} = scope), do: {:ok, scope}

  defp validate_user(%Scope{user_id: user_id} = scope) do
    case Repo.get(User, user_id) do
      nil -> invalid_scope("user not found", %{user_id: user_id})
      _user -> {:ok, scope}
    end
  end

  defp validate_enrollment(%Scope{enrollment_id: nil} = scope), do: {:ok, scope}

  defp validate_enrollment(%Scope{enrollment_id: enrollment_id} = scope) do
    case Repo.get(Enrollment, enrollment_id) do
      nil ->
        invalid_scope("enrollment not found", %{enrollment_id: enrollment_id})

      enrollment ->
        validate_enrollment_scope(scope, enrollment)
    end
  end

  defp validate_enrollment_scope(scope, enrollment) do
    cond do
      not is_nil(scope.section_id) and enrollment.section_id != scope.section_id ->
        invalid_scope("enrollment does not belong to section", %{
          enrollment_id: enrollment.id,
          section_id: scope.section_id,
          actual_section_id: enrollment.section_id
        })

      not is_nil(scope.user_id) and enrollment.user_id != scope.user_id ->
        invalid_scope("enrollment does not belong to user", %{
          enrollment_id: enrollment.id,
          user_id: scope.user_id,
          actual_user_id: enrollment.user_id
        })

      true ->
        {:ok, %{scope | section_id: enrollment.section_id, user_id: enrollment.user_id}}
    end
  end

  @doc false
  def ensure_definition_in_scope(schema, scope) do
    cond do
      schema.project_id != scope.project_id ->
        invalid_scope("experiment does not belong to project")

      not is_nil(scope.section_id) and
          not Repo.exists?(
            from(experiment_section in ExperimentSection,
              join: experiment in ExperimentDefinition,
              on: experiment.id == experiment_section.experiment_id,
              join: section in Section,
              on: section.id == experiment_section.section_id,
              join: spp in SectionsProjectsPublications,
              on:
                spp.section_id == section.id and
                    spp.project_id == experiment.project_id,
              where:
                experiment.id == ^schema.id and
                  experiment_section.section_id == ^scope.section_id and
                    section.status == :active
            )
          ) ->
        invalid_scope("experiment does not belong to section")

      true ->
        :ok
    end
  end

  defp invalid_scope(message, details \\ %{}) do
    {:error, %ExperimentError{type: :invalid_scope, message: message, details: details}}
  end
end
