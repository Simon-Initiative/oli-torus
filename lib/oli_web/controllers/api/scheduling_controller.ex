defmodule OliWeb.Api.SchedulingController do
  @moduledoc """
  Endpoint for accessing and updating soft scheduled
  course resources.
  """

  alias OpenApiSpex.Schema
  alias OliWeb.Common.SessionContext
  alias Oli.Delivery.Sections.SchedulingFacade
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResource

  import OliWeb.Api.Helpers

  use OliWeb, :controller
  use OpenApiSpex.Controller

  @moduledoc tags: ["Scheduling"]

  defmodule ScheduledResourcesUpdateRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Scheduled resources batch update request",
      description: "The request body to update a batch of section resources",
      type: :object,
      properties: %{
        updates: %Schema{
          type: :list,
          description: "List of the resources"
        }
      },
      required: [:updates],
      example: %{
        "updates" => [
          %{
            "id" => 1,
            "start_date" => nil,
            "end_date" => "2023-03-19",
            "scheduling_type" => "read_by"
          },
          %{
            "id" => 2,
            "start_date" => nil,
            "end_date" => "2023-03-29 11:20:02",
            "scheduling_type" => "due_by"
          }
        ]
      }
    })
  end

  defmodule ScheduledResourceUpdateResult do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Scheduled resource update result",
      description: "A count of number of scheduled resources updated",
      type: :object,
      properties: %{
        count: %Schema{
          type: :number,
          description: "Count of the resources updated"
        },
        result: %Schema{type: :string, description: "success"}
      },
      required: [:count, :result],
      example: %{
        "result" => "success",
        "count" => 5
      }
    })
  end

  defmodule ScheduledResourceResult do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Scheduled resource result",
      description: "A collection of scheduled resources",
      type: :object,
      properties: %{
        resources: %Schema{
          type: :list,
          description: "List of the resources"
        },
        result: %Schema{type: :string, description: "success"}
      },
      required: [:resources, :result],
      example: %{
        "result" => "success",
        "resources" => [
          %{
            "id" => 1,
            "title" => "Introduction",
            "children" => [],
            "resource_type_id" => 1,
            "graded" => false,
            "start_date" => "2023-02-03",
            "end_date" => "2023-02-09",
            "scheduling_type" => "read_by",
            "resource_id" => 24523
          }
        ]
      }
    })
  end

  @doc """
  Access all schedulable section resources for a course section.
  """
  @doc parameters: [
         section_slug: [
           in: :path,
           schema: %OpenApiSpex.Schema{type: :string},
           required: true,
           description: "The section identifier"
         ]
       ],
       responses: %{
         200 =>
           {"Scheduled resources result", "application/json",
            OliWeb.Api.SchedulingController.ScheduledResourceResult}
       }
  def index(conn, _) do
    section = conn.assigns.section

    if can_access_section?(conn, section) do
      resources =
        SchedulingFacade.retrieve(section)
        |> serialize_resource()

      json(conn, %{"result" => "success", "resources" => resources})
    else
      error(conn, 401, "Unauthorized")
    end
  end

  @doc """
  Access all schedulable section resources for a course section.
  """
  @doc parameters: [
         section_slug: [
           in: :path,
           schema: %OpenApiSpex.Schema{type: :string},
           required: true,
           description: "The section identifier"
         ]
       ],
       request_body:
         {"Request body for issuing an update request", "application/json",
          OliWeb.Api.SchedulingController.ScheduledResourcesUpdateRequest, required: true},
       responses: %{
         200 =>
           {"Scheduled resources update result", "application/json",
            OliWeb.Api.SchedulingController.ScheduledResourceUpdateResult}
       }
  def update(conn, %{"updates" => updates}) do
    section = conn.assigns.section

    context = SessionContext.init(conn)

    if can_access_section?(conn, section) do
      case SchedulingFacade.update(section, updates, context.local_tz) do
        {:ok, count} -> json(conn, %{"result" => "success", "count" => count})
        {:error, :missing_update_parameters} -> error(conn, 400, "Missing update parameters")
        e -> error(conn, 500, e)
      end
    else
      error(conn, 401, "Unauthorized")
    end
  end

  # Restrict access to enrolled instructors, LMS admins, or system
  # (authoring) admins
  defp can_access_section?(conn, section) do
    Sections.is_instructor?(conn.assigns.current_user, section.slug) or
      Oli.Accounts.is_admin?(conn.assigns.current_author) or
      Sections.is_admin?(conn.assigns.current_user, section.slug)
  end

  defp serialize_resource(resources) when is_list(resources) do
    Enum.map(resources, fn p -> serialize_resource(p) end)
  end

  defp serialize_resource(%SectionResource{} = sr) do
    %{
      "id" => sr.id,
      "title" => sr.title,
      "children" => sr.children,
      "resource_type_id" => sr.resource_type_id,
      "graded" => sr.graded,
      "start_date" => sr.start_date,
      "end_date" => sr.end_date,
      "scheduling_type" => sr.scheduling_type,
      "resource_id" => sr.resource_id,
      "manually_scheduled" => sr.manually_scheduled,
      "numbering_index" => sr.numbering_index,
      "numbering_level" => sr.numbering_level
    }
  end
end
