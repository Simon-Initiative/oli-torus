defmodule Oli.Search.EmbeddingsTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Search.RevisionEmbedding
  use OliWeb.ConnCase

  import Oli.Factory
  import Mox

  alias Oli.Resources.ResourceType
  alias Oli.Search.Embeddings
  alias Oli.Test.MockOpenAIClient

  describe "embedding_for_input/1" do
    test "returns the embedding for the input" do
      input = "This is a test"
      expected_embedding = "some-embedding"

      MockOpenAIClient
      |> expect(:embeddings, fn _args, _opts ->
        {:ok, %{data: [%{"embedding" => expected_embedding}]}}
      end)

      assert {:ok, embedding} = Embeddings.embedding_for_input(input)
      assert expected_embedding == embedding
    end

    test "returns the error if the request fails" do
      input = "This is a test"

      MockOpenAIClient
      |> expect(:embeddings, fn _args, _opts ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = Embeddings.embedding_for_input(input)
    end
  end

  describe "by_revision_id/1" do
    test "returns the embeddings for a revision id" do
      revision = insert(:revision)

      insert(:revision_embedding,
        revision: revision,
        content: "First embedding content",
        embedding: Pgvector.new(Enum.to_list(1..1536))
      )

      insert(:revision_embedding,
        revision: revision,
        content: "Second embedding content",
        embedding: Pgvector.new(Enum.to_list(2..1537))
      )

      [rev_embed_1, rev_embed_2] =
        Embeddings.by_revision_id(revision.id) |> Enum.sort_by(& &1.content)

      assert rev_embed_1.content == "First embedding content"
      assert rev_embed_1.embedding == Pgvector.new(Enum.to_list(1..1536))
      assert rev_embed_2.content == "Second embedding content"
      assert rev_embed_2.embedding == Pgvector.new(Enum.to_list(2..1537))
    end
  end

  describe "update_by_revision_ids/3" do
    test "schedules an oban job for each revision id when the third argument is false (or not provided)" do
      %Oli.Resources.Revision{id: revision_1_id} = insert(:revision)
      %Oli.Resources.Revision{id: revision_2_id} = insert(:revision)
      %Oli.Resources.Revision{id: revision_3_id} = insert(:revision)

      assert [
               %Oban.Job{
                 worker: "Oli.Search.EmbeddingWorker",
                 args: %{"publication_id" => 2, "revision_id" => ^revision_1_id}
               },
               %Oban.Job{
                 worker: "Oli.Search.EmbeddingWorker",
                 args: %{"publication_id" => 2, "revision_id" => ^revision_2_id}
               },
               %Oban.Job{
                 worker: "Oli.Search.EmbeddingWorker",
                 args: %{"publication_id" => 2, "revision_id" => ^revision_3_id}
               }
             ] =
               Embeddings.update_by_revision_ids([revision_1_id, revision_2_id, revision_3_id], 2)
    end

    test "inserts the revision_embeddings for each revision id when the third argument is true" do
      %Oli.Resources.Revision{id: revision_1_id} =
        insert(:revision, title: "Example revision 1", resource_type_id: 1)

      %Oli.Resources.Revision{id: revision_2_id} =
        insert(:revision, title: "Example revision 2", resource_type_id: 1)

      %Oli.Resources.Revision{id: revision_3_id} =
        insert(:revision, title: "Example revision 3", resource_type_id: 1)

      expected_embedding_1 = Pgvector.new(Enum.to_list(1..1536))
      expected_embedding_2 = Pgvector.new(Enum.to_list(2..1537))
      expected_embedding_3 = Pgvector.new(Enum.to_list(3..1538))

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

      expect(MockOpenAIClient, :embeddings, 1, fn _params, _config ->
        {:ok,
         %{
           data: [
             %{
               "embedding" => expected_embedding_3,
               "index" => 0,
               "object" => "embedding"
             }
           ],
           model: "text-embedding-ada-002",
           object: "list",
           usage: %{"prompt_tokens" => 8, "total_tokens" => 8}
         }}
      end)

      Embeddings.update_by_revision_ids([revision_1_id, revision_2_id, revision_3_id], 2, true)

      assert [%RevisionEmbedding{content: "Example revision 1", embedding: ^expected_embedding_1}] =
               Embeddings.by_revision_id(revision_1_id)

      assert [%RevisionEmbedding{content: "Example revision 2", embedding: ^expected_embedding_2}] =
               Embeddings.by_revision_id(revision_2_id)

      assert [%RevisionEmbedding{content: "Example revision 3", embedding: ^expected_embedding_3}] =
               Embeddings.by_revision_id(revision_3_id)
    end
  end

  describe "update_all/2" do
    setup do
      build_project()
    end

    test "schedules an oban job for each revision when the second argument is false (or not provided)",
         %{
           publication: publication,
           page_revision: page_revision,
           page_2_revision: page_2_revision
         } do
      publication_id = publication.id
      page_revision_id = page_revision.id
      page_2_revision_id = page_2_revision.id

      Embeddings.update_all(publication_id)

      assert_enqueued(
        worker: Oli.Search.EmbeddingWorker,
        args: %{"publication_id" => publication_id, "revision_id" => page_revision_id}
      )

      assert_enqueued(
        worker: Oli.Search.EmbeddingWorker,
        args: %{"publication_id" => publication_id, "revision_id" => page_2_revision_id}
      )
    end

    # MER-3983
    @tag :skip
    test "inserts the revision_embeddings for each revision id when the third argument is true",
         %{
           publication: publication,
           page_revision: page_revision,
           page_2_revision: page_2_revision
         } do
      expected_embedding_1 = Pgvector.new(Enum.to_list(1..1536))
      expected_embedding_2 = Pgvector.new(Enum.to_list(2..1537))

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

      Embeddings.update_all(publication.id, true)

      assert [%RevisionEmbedding{content: "revision A", embedding: ^expected_embedding_1}] =
               Embeddings.by_revision_id(page_revision.id)

      assert [%RevisionEmbedding{content: "revision B", embedding: ^expected_embedding_2}] =
               Embeddings.by_revision_id(page_2_revision.id)
    end
  end

  describe "revisions_to_embed/1" do
    setup do
      build_project()
    end

    test "returns the page revisions without embeddings for a publication",
         %{
           publication: publication,
           page_revision: page_revision,
           page_2_revision: page_2_revision
         } do
      # Create an embedding for page 1
      expect(MockOpenAIClient, :embeddings, 1, fn _params, _config ->
        {:ok,
         %{
           data: [
             %{
               "embedding" => Pgvector.new(Enum.to_list(1..1536)),
               "index" => 0,
               "object" => "embedding"
             }
           ],
           model: "text-embedding-ada-002",
           object: "list",
           usage: %{"prompt_tokens" => 8, "total_tokens" => 8}
         }}
      end)

      Embeddings.update_by_revision_ids([page_revision.id], publication.id, true)

      assert [page_id] =
               Embeddings.revisions_to_embed(publication.id)

      assert page_id == page_2_revision.id
    end
  end

  describe "project_embeddings_summary/1" do
    setup do
      build_project()
    end

    test "returns the embeddings summary for a project",
         %{
           publication: publication,
           page_revision: page_revision
         } do
      # Create an embedding for page 1
      expect(MockOpenAIClient, :embeddings, 1, fn _params, _config ->
        {:ok,
         %{
           data: [
             %{
               "embedding" => Pgvector.new(Enum.to_list(1..1536)),
               "index" => 0,
               "object" => "embedding"
             }
           ],
           model: "text-embedding-ada-002",
           object: "list",
           usage: %{"prompt_tokens" => 8, "total_tokens" => 8}
         }}
      end)

      Embeddings.update_by_revision_ids([page_revision.id], publication.id, true)
      Embeddings.update_by_revision_ids([page_revision.id], publication.id, true)
      Embeddings.update_by_revision_ids([page_revision.id], publication.id, true)

      assert %{total_embedded: 3, total_revisions_embedded: 1, total_to_embed: 1} =
               Embeddings.project_embeddings_summary(publication.id)
    end
  end

  defp build_project() do
    author = insert(:author)
    project = insert(:project, authors: [author])

    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
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
        published: DateTime.utc_now()
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
end
