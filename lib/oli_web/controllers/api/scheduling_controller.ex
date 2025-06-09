defmodule OliWeb.Api.SchedulingController do
  @moduledoc """
  Endpoint for accessing and updating soft scheduled
  course resources.
  """

  alias OpenApiSpex.Schema
  alias OliWeb.Common.SessionContext
  alias Oli.Delivery.Sections.Scheduling
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Accounts

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
            "end_date" => "2023-03-19 23:59:59",
            "scheduling_type" => "read_by",
            "removed_from_schedule" => false
          },
          %{
            "id" => 2,
            "start_date" => nil,
            "end_date" => "2023-03-29 11:20:02",
            "scheduling_type" => "due_by",
            "removed_from_schedule" => true
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
            "resource_id" => 24523,
            "removed_from_schedule" => false
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
    ctx = SessionContext.init(conn)

    if can_access_section?(conn, section) do
      resources =
        Scheduling.retrieve(section)
        |> serialize_resource(ctx.local_tz)

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
    ctx = SessionContext.init(conn)

    if can_access_section?(conn, section) do
      case Scheduling.update(section, updates, ctx.local_tz) do
        {:ok, count} ->
          json(conn, %{"result" => "success", "count" => count})

        {:error, :missing_update_parameters} ->
          error(conn, 400, "Missing update parameters")

        e ->
          error(conn, 500, e)
      end
    else
      error(conn, 401, "Unauthorized")
    end
  end

  def clear(conn, %{"section_slug" => _section_slug}) do
    section = conn.assigns.section

    if can_access_section?(conn, section) do
      case Scheduling.clear(section) do
        {:ok, _} ->
          Oli.Delivery.DepotCoordinator.clear(
            Oli.Delivery.Sections.SectionResourceDepot.depot_desc(),
            section.id
          )

          json(conn, %{"result" => "success"})

        {:error, error} ->
          json(conn, %{"result" => "error", "error" => error})
      end
    else
      error(conn, 401, "Unauthorized")
    end
  end

  # Restrict access to enrolled instructors, LMS admins, or system
  # (authoring) admins
  defp can_access_section?(conn, section) do
    Sections.is_instructor?(conn.assigns.current_user, section.slug) or
      Accounts.at_least_content_admin?(conn.assigns.current_author) or
      Sections.is_admin?(conn.assigns.current_user, section.slug)
  end

  defp serialize_resource(resources, local_tz) when is_list(resources) do
    Enum.map(resources, fn p -> serialize_resource(p, local_tz) end)
  end

  defp serialize_resource(%SectionResource{} = sr, local_tz) do
    just_date = fn datetime ->
      case datetime do
        nil ->
          nil

        _ ->
          # The database is in UTC with a time, the UI wants just a date.
          # Need to make sure to shift that to the user's timezone before truncating off the time portion.
          {:ok, user_tz_date} = DateTime.shift_zone(datetime, local_tz)
          DateTime.to_date(user_tz_date)
      end
    end

    %{
      "id" => sr.id,
      "title" => sr.title,
      "children" => sr.children,
      "resource_type_id" => sr.resource_type_id,
      "graded" => sr.graded,
      "start_date" =>
        if sr.graded do
          # Using start_date as the availablility date for graded items
          sr.start_date
        else
          sr.start_date |> just_date.()
        end,
      "end_date" =>
        if sr.scheduling_type == :due_by do
          sr.end_date
        else
          sr.end_date |> just_date.()
        end,
      "scheduling_type" => sr.scheduling_type,
      "resource_id" => sr.resource_id,
      "manually_scheduled" => sr.manually_scheduled,
      "numbering_index" => sr.numbering_index,
      "numbering_level" => sr.numbering_level,
      "removed_from_schedule" => sr.removed_from_schedule
    }
  end
end
