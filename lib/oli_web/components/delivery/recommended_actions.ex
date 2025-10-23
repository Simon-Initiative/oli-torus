defmodule OliWeb.Components.Delivery.RecommendedActions do
  use OliWeb, :verified_routes
  use Phoenix.Component

  alias OliWeb.Router.Helpers, as: Routes

  attr :section_slug, :string, required: true
  attr :has_scheduled_resources, :boolean, required: true
  attr :scoring_pending_activities_count, :integer, required: true
  attr :approval_pending_posts_count, :integer, required: true
  attr :has_pending_updates, :boolean, required: true
  attr :has_due_soon_activities, :boolean, required: true

  def render(
        %{
          has_scheduled_resources: true,
          scoring_pending_activities_count: 0,
          approval_pending_posts_count: 0,
          has_pending_updates: false,
          has_due_soon_activities: false
        } = assigns
      ) do
    ~H"""
    <div class="flex justify-center p-4">
      <span class="torus-span">No action needed</span>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div id="recommended_actions" class="grid grid-cols-2 gap-2">
      <%= if !@has_scheduled_resources do %>
        <.action_card to={
          Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.ScheduleView, @section_slug)
        }>
          <:icon><i class="fa-regular fa-calendar" /></:icon>
          <:title>Scheduling</:title>
          <:description>
            You have not defined a schedule for your course content
          </:description>
        </.action_card>
      <% end %>
      <%= if @scoring_pending_activities_count > 0 do %>
        <.action_card to={
          Routes.live_path(OliWeb.Endpoint, OliWeb.ManualGrading.ManualGradingView, @section_slug)
        }>
          <:icon><i class="fa-solid fa-circle-question" /></:icon>
          <:title>Score questions</:title>
          <:description>
            You have {@scoring_pending_activities_count} {if @scoring_pending_activities_count >
                                                               1,
                                                             do: "questions that are",
                                                             else: "question that is"} awaiting your manual scoring
          </:description>
        </.action_card>
      <% end %>
      <%= if @approval_pending_posts_count > 0 do %>
        <.action_card to={~p"/sections/#{@section_slug}/instructor_dashboard/discussions"}>
          <:icon><i class="fa-solid fa-circle-check" /></:icon>
          <:title>Approve Pending Posts</:title>
          <:description>
            You have {@approval_pending_posts_count} discussion {if @approval_pending_posts_count >
                                                                      1,
                                                                    do: "posts that are",
                                                                    else: "post that is"} pending your approval
          </:description>
        </.action_card>
      <% end %>
      <%= if @has_pending_updates do %>
        <.action_card to={
          Routes.source_materials_path(
            OliWeb.Endpoint,
            OliWeb.Delivery.ManageSourceMaterials,
            @section_slug
          )
        }>
          <:icon><i class="fa-solid fa-rotate" /></:icon>
          <:title>Pending course update</:title>
          <:description>
            There are available course content updates that you have not accepted
          </:description>
        </.action_card>
      <% end %>
      <%= if @has_due_soon_activities do %>
        <.action_card to={
          ~p"/sections/#{@section_slug}/instructor_dashboard/insights/scored_activities"
        }>
          <:icon><i class="fa-solid fa-hourglass-half" /></:icon>
          <:title>Remind Students of Deadlines</:title>
          <:description>
            There are assessments due soon, review and remind students
          </:description>
        </.action_card>
      <% end %>
    </div>
    """
  end

  slot :title, required: true
  slot :description, required: true
  slot :icon, required: true
  attr :to, :string, required: true

  defp action_card(assigns) do
    ~H"""
    <.link
      navigate={@to}
      class="group border border-gray-200 dark:border-gray-600 rounded p-3 pl-8 flex flex-col justify-center cursor-pointer hover:bg-delivery-primary-50 active:bg-delivery-primary active:text-white hover:no-underline"
    >
      <div class="flex items-center gap-2">
        {render_slot(@icon)}
        <h4>{render_slot(@title)}</h4>
      </div>
      <span class="torus-span group-hover:text-gray-500 group-active:text-white">
        {render_slot(@description)}
      </span>
    </.link>
    """
  end
end
