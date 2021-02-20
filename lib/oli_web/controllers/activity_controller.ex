defmodule OliWeb.ActivityController do
  use OliWeb, :controller
  use OpenApiSpex.Controller

  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Accounts
  alias Oli.Delivery.Attempts
  alias Oli.Delivery.Attempts.StudentInput
  alias OliWeb.Common.Breadcrumb
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.ApiSchemas

  import OliWeb.ProjectPlugs

  plug :fetch_project when action in [:edit]
  plug :authorize_project when action in [:edit]

  @moduledoc tags: ["Storage Service"]

  @moduledoc """
  The storage service allows activity implementations to read, write, update
  and delete documents associated with an activity instance.
  """

  alias OpenApiSpex.Schema

  @doc false
  def edit(conn, %{
        "project_id" => project_slug,
        "revision_slug" => revision_slug,
        "activity_slug" => activity_slug
      }) do
    author = conn.assigns[:current_author]
    is_admin? = Accounts.is_admin?(author)

    # full title, short title, link, action descriptions

    case ActivityEditor.create_context(project_slug, revision_slug, activity_slug, author) do
      {:ok, context} ->
        render(conn, "edit.html",
          active: :curriculum,
          breadcrumbs:
            Breadcrumb.trail_to(project_slug, revision_slug) ++
              [Breadcrumb.new(%{full_title: context.title})],
          project_slug: project_slug,
          is_admin?: is_admin?,
          activity_slug: activity_slug,
          script: context.authoringScript,
          context: Jason.encode!(context)
        )

      {:error, :not_found} ->
        render(conn, OliWeb.SharedView, "_not_found.html",
          breadcrumbs: [
            Breadcrumb.curriculum(project_slug),
            Breadcrumb.new(%{full_title: "Not Found"})
          ]
        )
    end
  end

  defmodule DocumentAttributes do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Activity document attributes",
      description: "The top-level attributes of activity documents",
      type: :object,
      properties: %{
        title: %Schema{type: :string, description: "Title of this document"},
        objectives: %Schema{type: :object, description: "Per part objective mapping"},
        content: %Schema{type: :object, description: "Delivery specific content"},
        authoring: %Schema{type: :object, description: "The authoring specific portion of the content"}
      },
      required: [],
      example: %{
        "title" => "Adaptive Activity Ensemble C",
        "objectives" => %{},
        "content" => %{"items" => ["1", "2"]}
      }
    })
  end


  defmodule BulkDocumentResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Bulk retrieval document response",
      description: "The response for a bulk document fetch operation",
      type: :object,
      properties: %{
        results: %Schema{type: :list, description: "Collection of document attribute instances"}
      },
      required: [:results],
      example: %{
        "result" => "success",
        "results" => []
      }
    })
  end

  defmodule BulkDocumentRequestBody do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Bulk retrieval document request body",
      description: "The request body for a bulk document fetch operation",
      type: :object,
      properties: %{
        resourceIds: %Schema{type: :list, description: "Array of resource identifiers of documents being requested"}
      },
      required: [:resourceIds],
      example: %{
        "resourceIds" => ["id1", "id2", "id3"]
      }
    })
  end

  @doc """
  Create a new secondary document for an activity.

  Torus activities are comprised of one primary document and zero or more secondary documents. While Torus
  creates the primary document for an activity instance, secondary document creation is entirely the responsibility
  of the activity implementation.

  """
  @doc parameters: [
    project: [in: :url, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The project identifier"],
    resource: [in: :url, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The activity identifier that this document will be secondary to"]
  ],
  request_body: {"Attributes for the document", "application/json", OliWeb.ActivityController.DocumentAttributes, required: true},
  responses: %{
    201 => {"Creation Response", "application/json", ApiSchemas.CreationResponse}
  }
  def create_secondary(conn, %{
        "project" => project_slug,
        "resource" => activity_id
      }) do

    author = conn.assigns[:current_author]
    update = conn.body_params

    case ActivityEditor.create_secondary(project_slug, activity_id, author, update) do
      {:ok, revision} ->
        conn
        |> put_status(:created) # This sets status code 201 instead of 200
        |> json(%{"result" => "success", "resourceId" => revision.resource_id})

      {:error, {:invalid_update_field}} ->
        error(conn, 400, "invalid update field")

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:not_authorized}} ->
        error(conn, 403, "unauthorized")

      _ ->
        error(conn, 500, "server error")
    end

  end

  @doc false
  def create(conn, %{
        "project" => project_slug,
        "activity_type" => activity_type_slug,
        "model" => model,
        "objectives" => objectives
      }) do
    author = conn.assigns[:current_author]

    case ActivityEditor.create(project_slug, activity_type_slug, author, model, objectives) do
      {:ok, {%{slug: slug}, transformed}} ->
        json(conn, %{"type" => "success", "revisionSlug" => slug, "transformed" => transformed})

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:not_authorized}} ->
        error(conn, 403, "unauthorized")

      _ ->
        error(conn, 500, "server error")
    end
  end

  defp document_to_result(nil) do
    %{
      "result" => "failed"
    }
  end

  defp document_to_result(%{objectives: objectives, title: title, content: content}) do
    %{
      "result" => "success",
      "objectives" => objectives,
      "title" => title,
      "content" => Map.delete(content, "authoring"),
      "authoring" => Map.get(content, "authoring")
    }
  end

  @doc """
  Retrieve a document for an activity in an authoring context.

  This retrieves the unpublished revision of an activity document, either a primary or secondary
  document.
  """
  @doc parameters: [
    project: [in: :url, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The project identifier"],
    resource: [in: :url, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The activity document identifier"]
  ],
  responses: %{
    200 => {"Retrieval Response", "application/json", OliWeb.ActivityController.DocumentAttributes}
  }
  def retrieve(conn, %{
    "project" => project_slug,
    "resource" => activity_id
  }) do
    author = conn.assigns[:current_author]

    case ActivityEditor.retrieve(project_slug, activity_id, author) do
      {:ok, rev} -> json(conn, document_to_result(rev))
      {:error, {:not_found}} -> error(conn, 404, "not found")
      _ -> error(conn, 500, "server error")
    end

  end

  @doc """
  Bulk retrieve documents for an activity in an authoring context.

  This retrieves the unpublished revision of activity documents.
  """
  @doc parameters: [
    project: [in: :url, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The project identifier"]
  ],
  request_body: {"Attributes for the document", "application/json", OliWeb.ActivityController.BulkDocumentRequestBody, required: true},
  responses: %{
    200 => {"Retrieval Response", "application/json", OliWeb.ActivityController.BulkDocumentResponse}
  }
  def bulk_retrieve(conn, %{
    "project" => project_slug,
    "resourceIds" => activity_ids
  }) do
    author = conn.assigns[:current_author]

    case ActivityEditor.retrieve_bulk(project_slug, activity_ids, author) do
      {:ok, revisions} ->
        json(conn, %{"result" => "success", "results" => Enum.map(revisions, &document_to_result/1)})

      {:error, {:not_found}} -> error(conn, 404, "not found")
      _ -> error(conn, 500, "server error")
    end

  end

  defp document_to_delivery_result(%{title: title, content: content}) do
    %{
      "result" => "success",
      "title" => title,
      "content" => Map.delete(content, "authoring")
    }
  end

  @doc """
  Retrieve a document for an activity for delivery purposes.

  This retrieves the published revision of an activity document, either a primary or secondary
  document, for a particular course section.
  """
  @doc parameters: [
    course: [in: :url, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The course identifier"],
    resource: [in: :url, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The activity document identifier"]
  ],
  responses: %{
    200 => {"Retrieval Response", "application/json", OliWeb.ActivityController.DocumentAttributes}
  }
  def retrieve_delivery(conn, %{
    "course" => course,
    "resource" => activity_id
  }) do

    user = conn.assigns.current_user

    case Sections.get_section_by(id: course) do

      nil -> error(conn, 404, "not found")

      section ->
        if Sections.is_enrolled?(user.id, section.context_id) do

          case DeliveryResolver.from_resource_id(section.context_id, activity_id) do
            nil -> error(conn, 404, "not found")

            rev -> json(conn, document_to_delivery_result(rev))
          end

        else
          error(conn, 403, "unauthorized")
        end

    end

  end

  @doc """
  Retrieve a document for an activity for delivery purposes.

  This retrieves the published revision of an activity document, either a primary or secondary
  document, for a particular course section.
  """
  @doc parameters: [
    course: [in: :url, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The course identifier"]
  ],
  responses: %{
    200 => {"Retrieval Response", "application/json", OliWeb.ActivityController.BulkDocumentResponse}
  }
  def bulk_retrieve_delivery(conn, %{
    "course" => course,
    "resourceIds" => activity_ids
  }) do

    user = conn.assigns.current_user

    case Sections.get_section_by(id: course) do

      nil -> error(conn, 404, "not found")

      section ->
        if Sections.is_enrolled?(user.id, section.context_id) do

          case DeliveryResolver.from_resource_id(section.context_id, activity_ids) do
            nil -> error(conn, 404, "not found")

            revisions -> json(conn, %{"result" => "success", "results" => Enum.map(revisions, &document_to_delivery_result/1)})
          end

        else
          error(conn, 403, "unauthorized")
        end

    end

  end

  @doc """
  Update a document for an activity.

  This operation will update one or more of the top-level document attributes (`title`, `objectives`, `content`, `authoring`) for
  either primary or secondary activity documents.

  This operation must be performed in the context of an exclusive write lock to avoid concurrent updates. The identifier of the
  lock must be specificed via the `lock` query parameter.
  """
  @doc parameters: [
    project: [in: :url, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The project identifier"],
    resource: [in: :url, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The activity document identifier"],
    lock: [in: :query, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The lock identifier that this operation will be performed within"]
  ],
  request_body: {"Attributes for the document", "application/json", OliWeb.ActivityController.DocumentAttributes, required: true},
  responses: %{
    200 => {"Update Response", "application/json", ApiSchemas.UpdateResponse}
  }
  def update(conn, %{
        "project" => project_slug,
        "lock" => lock_id,
        "resource" => activity_id
      }) do

    author = conn.assigns[:current_author]


    update = conn.body_params

    case ActivityEditor.edit(project_slug, lock_id, activity_id, author.email, update) do
      {:ok, _} -> json(conn, %{"result" => "success"})
      {:error, {:invalid_update_field}} -> error(conn, 400, "invalid update field")
      {:error, {:not_found}} -> error(conn, 404, "not found")
      {:error, {:not_authorized}} -> error(conn, 403, "unauthorized")
      _ -> error(conn, 500, "server error")
    end
  end

  @doc false
  def evaluate(conn, %{"model" => model, "partResponses" => part_inputs}) do
    parsed =
      Enum.map(part_inputs, fn %{"attemptGuid" => part_id, "response" => input} ->
        %{part_id: part_id, input: %StudentInput{input: Map.get(input, "input")}}
      end)

    case Attempts.perform_test_evaluation(model, parsed) do
      {:ok, evaluations} -> json(conn, %{"result" => "success", "evaluations" => evaluations})
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  @doc false
  def transform(conn, %{"model" => model}) do
    case Attempts.perform_test_transformation(model) do
      {:ok, transformed} -> json(conn, %{"result" => "success", "transformed" => transformed})
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  @doc """
  Delete a secondary document for an activity.

  This operation will mark a secondary document as deleted, but only for the current unpublished revision.

  This operation must be performed in the context of an exclusive write lock to avoid concurrent updates. The identifier of the
  lock must be specificed via the `lock` query parameter.
  """
  @doc parameters: [
    project: [in: :url, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The project identifier"],
    resource: [in: :url, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The activity identifier that this document will be secondary to"],
    lock: [in: :query, schema: %OpenApiSpex.Schema{type: :string}, required: true, description: "The lock identifier that this operation will be performed within"]
  ],
  responses: %{
    200 => {"Deletion Response", "application/json", ApiSchemas.UpdateResponse}
  }
  def delete(conn, %{"project" => project_slug, "resource" => resource_id, "lock" => lock_id}) do

    author = conn.assigns[:current_author]

    case ActivityEditor.delete(project_slug, lock_id, resource_id, author) do
      {:ok, _} -> json(conn, %{"result" => "success"})
      {:error, {:not_applicable}} -> error(conn, 400, "not applicable to this resource")
      {:error, {:not_found}} -> error(conn, 404, "not found")
      {:error, {:not_authorized}} -> error(conn, 403, "unauthorized")
      _ -> error(conn, 500, "server error")
    end

  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end
