defmodule OliWeb.Qa.WarningDetails do

  use Phoenix.LiveComponent
  import OliWeb.Qa.Utils

  def render(assigns) do
    ~L"""
    <div class="review-card active" id="<%= @selected.id %>">
      <h4 class="d-flex">
        <div>
          Improvement opportunity on <%= OliWeb.Common.Links.resource_link(@selected.revision, @parent_pages, @project) %>
        </div>
        <div class="flex-fill"></div>
        <button class="btn btn-sm btn-secondary" phx-click="dismiss">
          <i class="fa fa-times"></i> Dismiss
        </button>
      </h4>
      <div class="bd-callout bd-callout-info">
        <h3><%= title_case(@selected.subtype) %> on <%= @selected.revision.resource_type.type %></h3>
        <%= explanatory_text(@selected.subtype) %>
      </div>
      <div class="alert alert-info">
        <strong>Action item</strong> <%= action_item(@selected.subtype) %>
        <%= if @selected.content do %>
          <%= Phoenix.HTML.raw(Oli.Rendering.Content.render(%Oli.Rendering.Context{user: @author}, @selected.content, Oli.Rendering.Content.Html)) %>
        <% end %>
      </div>
    </div>
    """
  end
end
