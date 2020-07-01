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

    results
    |> Enum.take_every(2)
    |> Enum.map(& %{
      id: Enum.at(&1, 0),
      content: Enum.at(&1, 2)
    })
  end

end
