defmodule Oli.Validation.PageResourceResolutionTest do
  use Oli.DataCase
  import Oli.Factory

  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.ResourceType
  alias Oli.Validation

  defp mapped(publication, author, type, attrs \\ []) do
    resource = insert(:resource)

    revision =
      insert(
        :revision,
        Keyword.merge(
          [
            resource: resource,
            author: author,
            resource_type_id: ResourceType.get_id_by_type(type)
          ],
          attrs
        )
      )

    insert(:published_resource,
      publication: publication,
      resource: resource,
      revision: revision,
      author: author
    )

    revision
  end

  test "one projected query resolves the full page and respects current project mappings" do
    author = insert(:author)
    %{project: project, publication: working} = insert_project_with_resource(author)
    %{publication: other} = insert_project_with_resource(author)
    published = insert(:publication, project: project, published: DateTime.utc_now())

    activity = mapped(working, author, "activity")
    tag = mapped(working, author, "tag")
    objective = mapped(working, author, "objective")
    deleted = mapped(working, author, "activity", deleted: true)
    foreign = mapped(other, author, "activity")
    published_only = mapped(published, author, "activity")
    blueprint = mapped(working, author, "activity", resource_scope: :blueprint)
    # A newer unmapped revision does not supersede the working-publication snapshot.
    insert(:revision,
      resource: Oli.Repo.get!(Oli.Resources.Resource, activity.resource_id),
      author: author,
      deleted: true
    )

    ids =
      Enum.map(
        [activity, tag, objective, deleted, foreign, published_only, blueprint],
        & &1.resource_id
      )

    handler = "page-domain-query-#{System.unique_integer([:positive])}"
    test_pid = self()
    :ok = :telemetry.attach(handler, [:oli, :repo, :query], &__MODULE__.query_event/4, test_pid)
    on_exit(fn -> :telemetry.detach(handler) end)

    assert AuthoringResolver.resource_types(project.slug, ids) == %{
             activity.resource_id => "activity",
             tag.resource_id => "tag",
             objective.resource_id => "objective"
           }

    assert_receive {:query, query}
    assert query =~ "publication_id"
    refute query =~ "\"content\""
    refute_received {:query, _}
    assert %{} = AuthoringResolver.resource_types(project.slug, [])
    refute_received {:query, _}

    content = %{
      "version" => "0.1.0",
      "model" => [
        %{"type" => "activity-reference", "activity_id" => activity.resource_id},
        %{
          "type" => "selection",
          "id" => "bank",
          "count" => 1,
          "logic" => %{
            "conditions" => %{
              "operator" => "all",
              "children" => [
                %{"fact" => "tags", "operator" => "contains", "value" => [tag.resource_id]},
                %{
                  "fact" => "objectives",
                  "operator" => "contains",
                  "value" => [objective.resource_id]
                }
              ]
            }
          }
        }
      ]
    }

    resolver = fn ids -> {:ok, AuthoringResolver.resource_types(project.slug, ids)} end
    assert :ok = Validation.validate_page_domain(content, resolver)
    assert_receive {:query, _}
    refute_received {:query, _}

    bad = put_in(content, ["model", Access.at(0), "activity_id"], foreign.resource_id)

    assert {:error, [%{code: "missing_resource", path: "/model/0/activity_id"}]} =
             Validation.validate_page_domain(bad, resolver)

    assert_receive {:query, _}
    refute_received {:query, _}
  end

  def query_event(_event, _measurements, metadata, test_pid) do
    case self() == test_pid do
      true -> send(test_pid, {:query, metadata.query})
      false -> :ok
    end
  end
end
