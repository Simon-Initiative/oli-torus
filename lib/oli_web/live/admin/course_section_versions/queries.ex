defmodule OliWeb.Admin.CourseSectionVersions.Queries do
  import Ecto.Query, warn: false

  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo

  def load(project_slug) do
    case Repo.get_by(Project, slug: project_slug) do
      nil ->
        {:error, :not_found}

      %Project{} = project ->
        remixed_section_ids =
          from(spp in SectionsProjectsPublications,
            where: spp.project_id == ^project.id,
            select: spp.section_id
          )

        sections =
          from(s in Section,
            where:
              s.status == :active and
                (s.base_project_id == ^project.id or s.id in subquery(remixed_section_ids)),
            order_by: [asc: s.title, asc: s.slug],
            select: %{
              id: s.id,
              base_project_id: s.base_project_id,
              type: s.type,
              title: s.title,
              slug: s.slug,
              end_date: s.end_date
            }
          )
          |> Repo.all()

        {:ok, build_matrix(project, sections)}
    end
  end

  defp build_matrix(project, sections) do
    primary_project_id = project.id
    section_ids = Enum.map(sections, & &1.id)
    rows = section_publication_rows(section_ids)
    base_projects = base_projects(sections)

    projects =
      [project | base_projects ++ Enum.map(rows, & &1.project)]
      |> Enum.uniq_by(& &1.id)
      |> order_projects(primary_project_id)
      |> attach_latest_publications()

    publications_by_section =
      Enum.reduce(rows, %{}, fn row, acc ->
        version = %{
          publication_id: row.publication.id,
          edition: row.publication.edition,
          major: row.publication.major,
          minor: row.publication.minor
        }

        Map.update(acc, row.section_id, %{row.project_id => version}, fn project_versions ->
          Map.put(project_versions, row.project_id, version)
        end)
      end)

    sections =
      Enum.map(sections, fn section ->
        Map.put(
          section,
          :publications_by_project_id,
          Map.get(publications_by_section, section.id, %{})
        )
      end)

    %{
      source: project,
      primary_project_id: primary_project_id,
      projects: projects,
      sections: sections
    }
  end

  defp section_publication_rows([]), do: []

  defp section_publication_rows(section_ids) do
    from(spp in SectionsProjectsPublications,
      join: p in Project,
      on: p.id == spp.project_id,
      join: pub in Publication,
      on: pub.id == spp.publication_id,
      where: spp.section_id in ^section_ids,
      select: %{
        section_id: spp.section_id,
        project_id: spp.project_id,
        project: p,
        publication: pub
      }
    )
    |> Repo.all()
  end

  defp base_projects(sections) do
    project_ids =
      sections
      |> Enum.map(& &1.base_project_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if Enum.empty?(project_ids) do
      []
    else
      from(p in Project,
        where: p.id in ^project_ids
      )
      |> Repo.all()
    end
  end

  defp order_projects(projects, primary_project_id) do
    projects
    |> Enum.sort_by(&{String.downcase(&1.title || ""), &1.slug || ""})
    |> Enum.sort_by(fn project -> if project.id == primary_project_id, do: 0, else: 1 end)
  end

  defp attach_latest_publications([]), do: []

  defp attach_latest_publications(projects) do
    project_ids = Enum.map(projects, & &1.id)

    latest_publications_by_project_id =
      from(pub in Publication,
        where: pub.project_id in ^project_ids and not is_nil(pub.published),
        order_by: [asc: pub.project_id, desc: pub.published, desc: pub.id],
        select: %{
          project_id: pub.project_id,
          publication_id: pub.id,
          edition: pub.edition,
          major: pub.major,
          minor: pub.minor
        }
      )
      |> Repo.all()
      |> Enum.uniq_by(& &1.project_id)
      |> Map.new(fn row -> {row.project_id, Map.delete(row, :project_id)} end)

    Enum.map(projects, fn project ->
      latest_publication = Map.get(latest_publications_by_project_id, project.id)

      %{
        id: project.id,
        title: project.title,
        slug: project.slug,
        latest_publication: latest_publication,
        latest_publication_id: latest_publication && latest_publication.publication_id
      }
    end)
  end
end
