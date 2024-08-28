defmodule OliWeb.Workspaces.CourseAuthor.Qa.WarningDetails do
  use OliWeb, :html
  import OliWeb.Workspaces.CourseAuthor.Qa.Utils
  alias OliWeb.Common.Links

  def render(assigns) do
    ~H"""
    <style>
      .delivery-container img {
        max-width: 300px;
      }
      .delivery-container iframe {
        max-width: 300px;
      }
    </style>
    <div class="review-card active" id={"#{@selected.id}"}>
      <h4 class="d-flex">
        <div>
          Improvement opportunity on <%= Links.resource_link(
            @selected.revision,
            @parent_pages,
            @project
          ) %>
        </div>
        <div class="flex-fill"></div>
        <button class="btn btn-sm btn-secondary" phx-click="dismiss">
          <i class="fa fa-times"></i> Dismiss
        </button>
      </h4>
      <div class="bd-callout bd-callout-info">
        <h3>
          <%= String.capitalize(@selected.subtype) %> on <%= @selected.revision.resource_type.type %>
        </h3>
        <%= explanatory_text(@selected.subtype, %{graded: @selected.revision.graded}) %>
      </div>
      <div class="alert alert-info">
        <strong>Action item</strong> <%= action_item(@selected.subtype, %{
          graded: @selected.revision.graded
        }) %>
        <div class="delivery-container">
          <.warning
            :if={@selected.content}
            selected={@selected}
            project_slug={@project.slug}
            author={@author}
          />
        </div>
      </div>
    </div>
    """
  end

  attr(:selected, :map, required: true)
  attr(:project_slug, :string, required: true)
  attr(:author, :map, required: true)

  def warning(
        %{selected: %{subtype: "No value provided for criteria in bank selection logic"}} =
          assigns
      ) do
    ~H"""
    <p>
      This page contains an activity bank selection whose logic, when tested by this QA Review run,
      did not yield activities to satisfy the specified criteria in the selection.
    </p>
    <p>
      Fix this issue by adding a value for the criteria in the
      <.link navigate={~p"/authoring/project/#{@project_slug}/resource/#{@selected.revision.slug}"}>
        selection logic in the page.
      </.link>
    </p>
    """
  end

  def warning(%{selected: %{content: %{"type" => "selection"}}} = assigns) do
    ~H"""
    <p>
      This page contains an activity bank selection whose logic, when tested by this QA Review run,
      did not yield enough activities to satisfy the specified count in the selection.
    </p>
    <p>
      Fix this issue by one of two ways:
    </p>
    <ol>
      <li>
        Edit the
        <.link navigate={~p"/authoring/project/#{@project_slug}/resource/#{@selected.revision.slug}"}>
          selection logic in the page
        </.link>
        to allow it to select more activities
      </li>
      <li>Create more banked activities to allow the selection to fill the specified count</li>
    </ol>
    """
  end

  def warning(assigns) do
    ~H"""
    <%= Phoenix.HTML.raw(
      Oli.Rendering.Content.render(
        %Oli.Rendering.Context{user: @author},
        @selected.content,
        Oli.Rendering.Content.Html
      )
    ) %>
    """
  end
end
