defmodule Oli.Search.EmbeddingWorkerTest do
  use Oban.Testing, repo: Oli.Repo
  use Oli.DataCase

  import Oli.Factory
  import Mox

  alias Oli.Resources.ResourceType
  alias Oli.Search.{Embeddings, EmbeddingWorker, RevisionEmbedding}
  alias Oli.Test.MockOpenAIClient

  defp create_project(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    objective_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 1"
      )

    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        objectives: %{
          "1" => [
            objective_1_revision.resource_id
          ]
        },
        title: "revision A"
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "revision B"
      )

    container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: [page_revision.resource_id, page_2_revision.resource_id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    all_revisions =
      [
        objective_1_revision,
        page_revision,
        page_2_revision,
        container_revision
      ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_revision.resource_id,
        published: nil
      })

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    [
      project: project,
      publication: publication,
      page_revision: page_revision,
      page_2_revision: page_2_revision,
      author: author,
      container_revision: container_revision
    ]
  end

  describe "Embedding worker" do
    setup [:create_project]

    test "calculates the revision embeddings when the job is performed", %{
      # conn: conn,
      # project: project,
      publication: publication,
      page_revision: page_revision,
      page_2_revision: page_2_revision
    } do
      expected_embedding_1 = Pgvector.new(Enum.to_list(1..1536))

      expect(MockOpenAIClient, :embeddings, 1, fn _params, _config ->
        {:ok,
         %{
           data: [
             %{
               "embedding" => expected_embedding_1,
               "index" => 0,
               "object" => "embedding"
             }
           ],
           model: "text-embedding-ada-002",
           object: "list",
           usage: %{"prompt_tokens" => 8, "total_tokens" => 8}
         }}
      end)

      # The worker upserts the embedding when executed
      assert :ok =
               perform_job(EmbeddingWorker, %{
                 publication_id: publication.id,
                 revision_id: page_revision.id
               })

      [%RevisionEmbedding{content: content, embedding: embedding}] =
        Embeddings.by_revision_id(page_revision.id)

      assert content == "revision A"
      assert embedding == expected_embedding_1

      expected_embedding_2 = Pgvector.new(Enum.to_list(2..1537))

      expect(MockOpenAIClient, :embeddings, 1, fn _params, _config ->
        {:ok,
         %{
           data: [
             %{
               "embedding" => expected_embedding_2,
               "index" => 0,
               "object" => "embedding"
             }
           ],
           model: "text-embedding-ada-002",
           object: "list",
           usage: %{"prompt_tokens" => 8, "total_tokens" => 8}
         }}
      end)

      assert :ok =
               perform_job(EmbeddingWorker, %{
                 publication_id: publication.id,
                 revision_id: page_2_revision.id
               })

      [%RevisionEmbedding{content: content_2, embedding: embedding_2}] =
        Embeddings.by_revision_id(page_2_revision.id)

      assert content_2 == "revision B"
      assert embedding_2 == expected_embedding_2
    end
  end
end
