defmodule Oli.Qa.Utils do
  import Ecto.Query, warn: false

  alias Oli.Resources.{ResourceType}
  alias Oli.Authoring.Course
  alias Oli.Publishing

  def elements_of_type(types, review) do
    project = Course.get_project!(review.project_id)
    publication_id = Publishing.get_unpublished_publication_by_slug!(project.slug).id
    page_id = ResourceType.get_id_by_type("page")
    activity_id = ResourceType.get_id_by_type("activity")

    item_types = types
    |> Enum.map(& ~s|@.type == "#{&1}"|)
    |> Enum.join(" || ")

    sql =
      """
      select
        rev.id,
        rev.title,
        jsonb_path_query(content, '$.** ? (#{item_types})')
      from published_resources as mapping
      join revisions as rev
      on mapping.revision_id = rev.id
      where mapping.publication_id = #{publication_id}
        and (rev.resource_type_id = #{page_id}
          or rev.resource_type_id = #{activity_id})
        and rev.deleted is false
      """

    {:ok, %{rows: results }} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    dedupe(results)
    |> Enum.map(& %{
      id: Enum.at(&1, 0),
      content: Enum.at(&1, 2)
    })
  end

    # The jsonb_path_query for elements, for some reason, duplicates results on a revision by
    # revision basis.  So if a particular page has one matching element it will
    # appear duplicated in the results.  If a revision has two matching elements they
    # appear duplicated, but the entire group is duplicated. Consider two pages, one with
    # a single matching element (an image) and another page with two matching image elements.
    #
    # Page1
    # --image1
    # Page2
    # --image2
    # --image3
    #
    # The jsonb_path_query above yields results like this:
    # Page1, image1
    # Page1, image1
    # Page2, image2
    # Page2, image3
    # Page2, image2
    # Page2, image3
    #
    # We need to split the results into groups according to the revision id,
    # then take only the first half of results for each revision
  defp dedupe(results) do
    groups = Enum.group_by(results, fn [id, _, _] -> id end)

    Map.keys(groups)
    |> Enum.reduce([], fn k, all ->
      items = Map.get(groups, k)
      all ++ Enum.take(items, div(length(items), 2))
    end)

  end

end
