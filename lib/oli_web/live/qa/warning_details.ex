defmodule OliWeb.Qa.WarningDetails do
  use Phoenix.LiveComponent
  import OliWeb.Qa.Utils
  alias OliWeb.Router.Helpers, as: Routes

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
          Improvement opportunity on <%= OliWeb.Common.Links.resource_link(
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
        <%= if @selected.content do %>
          <div class="delivery-container">
            <%= if @selected.content["type"] == "selection" do %>
              <p></p>
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
                  <a href={"#{Routes.resource_url(OliWeb.Endpoint, :edit, @project.slug, @selected.revision.slug)}##{@selected.content["id"]}"}>
                    selection logic in the page
                  </a>
                  to allow it to select more activities
                </li>
                <li>
                  Create more banked activities to allow the selection to fill the specified count
                </li>
              </ol>
            <% else %>
              <%= Phoenix.HTML.raw(
                Oli.Rendering.Content.render(
                  %Oli.Rendering.Context{user: @author},
                  @selected.content,
                  Oli.Rendering.Content.Html
                )
              ) %>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
