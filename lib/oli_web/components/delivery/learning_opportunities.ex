defmodule OliWeb.Components.Delivery.LearningOpportunities do
  use Phoenix.Component

  import OliWeb.Components.Delivery.Utils
  import OliWeb.Common.FormatDateTime

  alias OliWeb.Common.SessionContext

  defmodule LearningOpportunity do
    @enforce_keys [:type, :title, :progress, :complete_by_date, :open_href]

    defstruct [
      :type,
      :title,
      :progress,
      :complete_by_date,
      :open_href
    ]

    @type t() :: %__MODULE__{
            type: :course_content | :graded_assignment | :mission_activities,
            title: String.t(),
            progress:
              {:percent_complete, integer}
              | {:score, integer, integer}
              | {:activities_completed, integer, integer},
            complete_by_date: String.t(),
            open_href: String.t()
          }
  end

  attr(:ctx, SessionContext, required: true)

  def opportunities(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 shadow">
      <div class="p-4">
        <h6>Opportunities <span class="hidden lg:inline">for further learning</span></h6>
        <small class="text-gray-500">
          These are areas you could revisit.
        </small>
      </div>
      <%= for lo <- [
          %LearningOpportunity{
            type: :course_content,
            title: "1.0 Intro to Chemistry 101: Foundational Content",
            progress: {:percent_complete, 20},
            complete_by_date: date(~U[2023-10-03 12:00:00Z], @ctx),
            open_href: "#"
          },
          %LearningOpportunity{
            type: :graded_assignment,
            title: "1.0 Intro to Chemistry 101: Chemistry Assignment",
            progress: {:score, 3, 10},
            complete_by_date: date(~U[2023-10-03 12:00:00Z], @ctx),
            open_href: "#"
          },
          %LearningOpportunity{
            type: :mission_activities,
            title: "Mission Activity: Water Pollution on Planet Earth",
            progress: {:activities_completed, 5, 10},
            complete_by_date: date(~U[2023-10-03 12:00:00Z], @ctx),
            open_href: "#"
          }
        ] do %>
        <.learning_opportunity learning_opportunity={lo} />
      <% end %>
    </div>
    """
  end

  attr(:learning_opportunity, LearningOpportunity, required: true)

  def learning_opportunity(assigns) do
    ~H"""
    <div class="my-2 border-t border-gray-200 dark:border-gray-700">
      <div class="flex-1 rounded p-8 py-4 mb-2 last:mb-0 md:last:mb-2 md:mr-2">
        <div class="flex my-2">
          <span class={"rounded-full py-1 px-6 #{badge_bg_color(@learning_opportunity)} text-white"}>
            {badge_name(@learning_opportunity)}
          </span>
        </div>
        <div class="my-2">
          <span class="font-bold">{@learning_opportunity.title}</span>
        </div>
        <%= case @learning_opportunity.progress do %>
          <% {:percent_complete, percent} -> %>
            <.progress_bar width="200px" percent={percent} />
          <% {:score, score, out_of} -> %>
            <div class="my-2 flex flex-row items-center">
              <div>Score:</div>
              <div class="flex-1 ml-2 text-red-500">
                {"#{score}/#{out_of}"}
              </div>
            </div>
          <% {:activities_completed, completed, out_of} -> %>
            <div class="my-2 flex flex-row items-center">
              <div>Activities completed:</div>
              <div class="flex-1 ml-2 text-yellow-500">
                {"#{completed}/#{out_of}"}
              </div>
            </div>
        <% end %>
        <div class="my-2 flex flex-row">
          <div class="flex-1 bg-gray-100 dark:bg-gray-700 rounded p-2 text-center">
            Read by {@learning_opportunity.complete_by_date}
          </div>
          <div>
            <a
              href={@learning_opportunity.open_href}
              class="btn text-white hover:text-white inline-flex ml-2 bg-delivery-primary hover:bg-delivery-primary-600 active:bg-delivery-primary-700"
            >
              Open
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp badge_name(%LearningOpportunity{type: :course_content}), do: "Course Content"
  defp badge_name(%LearningOpportunity{type: :graded_assignment}), do: "Graded Assignment"
  defp badge_name(%LearningOpportunity{type: :mission_activities}), do: "Mission Activities"

  defp badge_bg_color(%LearningOpportunity{type: :course_content}), do: "bg-green-700"
  defp badge_bg_color(%LearningOpportunity{type: :graded_assignment}), do: "bg-fuchsia-800"
  defp badge_bg_color(%LearningOpportunity{type: :mission_activities}), do: "bg-blue-500"
end
