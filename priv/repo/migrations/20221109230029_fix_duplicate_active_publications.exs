defmodule Oli.Repo.Migrations.FixDuplicateActivePublications do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Repo

  require Logger

  def change do
    ## An active publication is indicated by having a null published field.
    ## The system expects there to only ever be a single active active publication.

    ## Find all duplicates
    # SELECT p2.project_id, p2.root_resource_id, COUNT(*) FROM published_resources as p0
    # INNER JOIN revisions r1 on p0.revision_id = r1.id
    # INNER JOIN publications p2 on p0.publication_id = p2.id
    # INNER JOIN projects p3 on p3.id = p2.project_id
    # WHERE p2.published IS NULL AND p0.resource_id = p2.root_resource_id
    # GROUP BY p2.project_id, p2.root_resource_id, p0.resource_id
    # HAVING COUNT(p0.resource_id) > 1;

    duplicate_active_publications =
      from(
        pr in "published_resources",
        inner_join: rev in "revisions",
        on: rev.id == pr.revision_id,
        inner_join: pub in "publications",
        on: pub.id == pr.publication_id,
        inner_join: proj in "projects",
        on: proj.id == pub.project_id,
        where: is_nil(pub.published) and pr.resource_id == pub.root_resource_id,
        group_by: [pub.project_id, pub.root_resource_id, pr.resource_id],
        having: count(pr.resource_id) > 1,
        select: %{
          project_id: pub.project_id,
          root_resource_id: pub.root_resource_id,
          count: count(pr.resource_id)
        }
      )
      |> Repo.all()

    Logger.info(
      "Identified #{Enum.count(duplicate_active_publications)} projects with duplicate active publications: #{Kernel.inspect(duplicate_active_publications)}"
    )

    if Enum.count(duplicate_active_publications) > 0 do
      Logger.info("Duplicates will be deleted leaving a single active publication")
    end

    ## Delete all duplicate active publications for a project except for the latest one
    # SELECT *
    # FROM publications as pub
    # WHERE pub.project_id = PROJECT_ID and pub.published IS NULL
    # ORDER BY pub.id ASC
    # LIMIT (
    #     SELECT COUNT(*)
    #     FROM publications as pub
    #     WHERE pub.project_id = PROJECT_ID and pub.published IS NULL
    # ) - 1;

    Enum.each(duplicate_active_publications, fn %{project_id: project_id, count: count} ->
      # to simplify the query, reuse the count already computed to determine limit
      duplicate_count = count - 1

      # delete_all doesn't support limit operator, so we perform this action in two separate steps
      publication_ids_to_remove =
        from(
          pub in "publications",
          where: pub.project_id == ^project_id and is_nil(pub.published),
          order_by: [asc: pub.id],
          limit: ^duplicate_count,
          select: pub.id
        )
        |> Repo.all()

      from(
        pub in "publications",
        where: pub.id in ^publication_ids_to_remove
      )
      |> Repo.delete_all()
    end)
  end
end
