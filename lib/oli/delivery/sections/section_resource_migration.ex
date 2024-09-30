defmodule Oli.Delivery.Sections.SectionResourceMigration do

  alias Oli.Repo
  import Ecto.Query
  alias Oli.Delivery.Sections.SectionResource

  def requires_migration?(section_id) do

    query = from sr in SectionResource,
            where: sr.section_id == ^section_id,
            select: sr.graded,
            limit: 1

    case Oli.Repo.all(query) do
      [nil] ->
        true
      _ ->
        false
    end

  end

  def migrate(section_id) do
    # update all SectionResource records to copy over the following fields form
    # the pinned revision:
    sql = """
    UPDATE section_resources
    SET
      project_slug = subquery.project_slug,
      title = subquery.title,
      graded = subquery.graded,
      resource_type_id = subquery.resource_type_id,
      revision_slug = subquery.revision_slug,
      purpose = subquery.purpose,
      duration_minutes = subquery.duration_minutes,
      intro_content = subquery.intro_content,
      intro_video = subquery.intro_video,
      poster_image = subquery.poster_image,
      objectives = subquery.objectives,
      relates_to = subquery.relates_to,
      activity_type_id = subquery.activity_type_id,
      revision_id = subquery.revision_id,
      updated_at = NOW()
    FROM (
        SELECT
          r.resource_id,
          proj.slug as project_slug,
          r.title,
          r.graded,
          r.resource_type_id,
          r.id as revision_id,
          r.slug as revision_slug,
          r.purpose,
          r.duration_minutes,
          r.intro_content,
          r.intro_video,
          r.poster_image,
          r.objectives,
          r.relates_to,
          r.activity_type_id
        FROM sections_projects_publications spp
        JOIN publications p ON p.id = spp.publication_id
        JOIN published_resources pr ON pr.publication_id = p.id
        JOIN revisions r ON r.id = pr.revision_id
        JOIN projects proj ON proj.id = spp.project_id
        WHERE spp.section_id = $1
    ) AS subquery
    WHERE section_resources.resource_id = subquery.resource_id
      AND section_resources.section_id = $2
    """

    case Ecto.Adapters.SQL.query(Repo, sql, [section_id, section_id]) do

      {:ok, %Postgrex.Result{num_rows: num_rows}} -> {:ok, num_rows}
      e -> e
    end
  end

end
