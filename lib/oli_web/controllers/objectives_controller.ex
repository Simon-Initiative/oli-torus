defmodule OliWeb.ObjectivesController do
  use OliWeb, :controller
  use OpenApiSpex.Controller

  @moduledoc tags: ["Objectives Service"]

  @moduledoc """
  The objectives service is a collection of endpoints intended to be
  used by the authoring implementation of an activity to access, create,
  and update the objectives present in a course project.
  """

  alias OpenApiSpex.Schema
  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Publishing.AuthoringResolver
  alias OliWeb.ApiSchemas

  import OliWeb.ProjectPlugs

  plug :fetch_project_api
  plug :authorize_project_api

  defmodule ObjectiveResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Objective",
      description: "A learning objective",
      type: :object,
      properties: %{
        id: %Schema{type: :integer, description: "The id of this objective"},
        title: %Schema{type: :string, description: "The title of the learning objective"},
        parentId: %Schema{
          type: :integer,
          description: "The id of the parent objective, if this is not a top-level objective"
        }
      },
      required: [:id, :title, :parentId],
      example: [
        %{
          "id" => 10,
          "title" => "Define and describe an important concept",
          "parentId" => nil
        },
        %{
          "id" => 124,
          "title" => "A more granular objective regarding this important concept",
          "parentId" => 10
        }
      ]
    })
  end

  @doc """
  List all learning objectives.
  """
  @doc parameters: [
         project: [
           in: :url,
           schema: %OpenApiSpex.Schema{type: :string},
           required: true,
           description: "The project id"
         ]
       ],
       responses: %{
         200 =>
           {"All objectives", "application/json", OliWeb.ObjectivesController.ObjectiveResponse}
       }
  def index(conn, _) do
    objectives =
      conn.assigns[:project]
      |> ObjectiveEditor.fetch_objective_mappings()
      |> Enum.map(fn %{revision: revision} -> revision end)
      |> to_parent_based_representation()

    json(conn, objectives)
  end

  # Convert a list of objectives from the database schema approach to hierarchy
  # reprensentation to an alternate hierarchy representation, one that simply specifies
  # a "parent_id" pointer to a parent objective (if one exists)
  defp to_parent_based_representation(revisions) do
    # create a map of ids to their parent ids
    parents =
      Enum.reduce(revisions, %{}, fn r, m ->
        Enum.reduce(r.children, m, fn c, n ->
          Map.put(n, c, r.resource_id)
        end)
      end)

    # now just transform the revision list to pair it down to including
    # id, title, and the new parent_id
    Enum.map(revisions, fn r ->
      %{
        id: r.resource_id,
        title: r.title,
        parentId: Map.get(parents, r.resource_id)
      }
    end)
  end

  defmodule ObjectiveUpdateAttributes do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Objective update attributes",
      description: "Attributes for updating objectives",
      type: :object,
      properties: %{
        title: %Schema{type: :string, description: "Title of this objective"}
      },
      required: [:title],
      example: %{
        "title" => "Learn to do a new skill"
      }
    })
  end

  @doc """
  Edit a learning objective.
  """
  @doc parameters: [
         project: [
           in: :url,
           schema: %OpenApiSpex.Schema{type: :string},
           required: true,
           description: "The project id"
         ],
         objective: [
           in: :url,
           schema: %OpenApiSpex.Schema{type: :string},
           required: true,
           description: "The objective id"
         ]
       ],
       request_body:
         {"Attributes for updating an objective", "application/json", ObjectiveUpdateAttributes,
          required: true},
       responses: %{
         200 => {"Update result", "application/json", ApiSchemas.UpdateResponse}
       }
  def update(conn, %{"objective" => objective_id}) do
    project = conn.assigns[:project]
    author = conn.assigns[:current_author]

    case conn.body_params["title"] do
      nil ->
        error(conn, 400, "Missing title")

      title ->
        with {:ok, %{slug: slug}} <-
               AuthoringResolver.from_resource_id(project.slug, objective_id)
               |> Oli.Utils.trap_nil(),
             {:ok, _} <- ObjectiveEditor.edit(slug, %{title: title}, author, project) do
          json(conn, %{"result" => "success"})
        else
          {:error, {:not_found}} -> error(conn, 404, "Not found")
          _ -> error(conn, 500, "Objective could not be updated")
        end
    end
  end

  defmodule ObjectiveCreationAttributes do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Objective creation attributes",
      description: "Attributes for creating objectives",
      type: :object,
      properties: %{
        title: %Schema{type: :string, description: "Title of this objective"},
        parentId: %Schema{
          type: :integer,
          description: "The parent objective to attach to, omit if top-level"
        }
      },
      required: [:title],
      example: %{
        "title" => "Learn to do a new skill"
      }
    })
  end

  @doc """
  Create a new learning objective.
  """
  @doc parameters: [
         project: [
           in: :url,
           schema: %OpenApiSpex.Schema{type: :string},
           required: true,
           description: "The project id"
         ]
       ],
       request_body:
         {"Attributes for creating an objective", "application/json", ObjectiveCreationAttributes,
          required: true},
       responses: %{
         201 => {"Creation result", "application/json", ApiSchemas.CreationResponse}
       }
  def create(conn, _) do
    project = conn.assigns[:project]
    author = conn.assigns[:current_author]

    parent_slug =
      case Map.get(conn.body_params, "parentId") do
        nil ->
          nil

        id ->
          case AuthoringResolver.from_resource_id(project.slug, id) do
            nil -> nil
            rev -> rev.slug
          end
      end

    case conn.body_params["title"] do
      nil ->
        error(conn, 400, "Missing title")

      title ->
        case ObjectiveEditor.add_new(%{title: title}, author, project, parent_slug) do
          {:ok, %{revision: revision}} ->
            conn
            # This sets status code 201 instead of 200
            |> put_status(:created)
            |> json(%{"result" => "success", "resourceId" => revision.resource_id})

          _ ->
            error(conn, 500, "Objective could not be created")
        end
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end
