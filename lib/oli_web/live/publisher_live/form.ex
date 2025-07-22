defmodule OliWeb.PublisherLive.Form do
  use OliWeb, :html

  attr(:changeset, :any, required: true)
  attr(:save, :any, required: true)
  attr(:display_labels, :boolean, default: true)

  def render(assigns) do
    assigns = assign(assigns, :changeset, to_form(assigns.changeset))

    ~H"""
    <.form for={@changeset} phx-submit={@save} class="flex flex-col gap-y-4">
      <div class="form-group mb-0">
        <%= if @display_labels do %>
          <div class="flex justify-between">
            <label for="publisher_name">Publisher Name</label>
            <%= if @changeset[:default] do %>
              <span class="badge badge-info">default</span>
            <% end %>
          </div>
        <% end %>

        <.input
          id="publisher_name"
          class="form-control"
          type="text"
          field={@changeset[:name]}
          placeholder="Name"
          maxlength="255"
        />
      </div>

      <div class="form-group mb-0">
        <%= if @display_labels do %>
          <label for="publisher_email">Publisher Email</label>
        <% end %>
        <.input
          id="publisher_email"
          class="form-control"
          type="text"
          field={@changeset[:email]}
          placeholder="Email"
          maxlength="255"
        />
      </div>

      <div class="form-group mb-0">
        <%= if @display_labels do %>
          <label for="publisher_address">Publisher Address</label>
        <% end %>
        <.input
          id="publisher_address"
          class="form-control"
          type="text"
          field={@changeset[:address]}
          placeholder="Address"
          maxlength="255"
        />
      </div>

      <div class="form-group mb-0">
        <%= if @display_labels do %>
          <label for="publisher_main_contact">Publisher Main Contact</label>
        <% end %>
        <.input
          id="publisher_main_contact"
          class="form-control"
          type="text"
          field={@changeset[:main_contact]}
          placeholder="Main Contact"
          maxlength="255"
        />
      </div>

      <div class="form-group mb-0">
        <%= if @display_labels do %>
          <label for="publisher_website_url">Publisher Website URL</label>
        <% end %>
        <.input
          id="publisher_website_url"
          class="form-control"
          type="text"
          field={@changeset[:website_url]}
          placeholder="Website URL"
          maxlength="255"
        />
      </div>

      <div class="form-group mb-0">
        <%= if @display_labels do %>
          <label for="publisher_knowledge_base_link">Knowledge Base Link</label>
        <% end %>
        <.input
          id="publisher_knowledge_base_link"
          class="form-control"
          type="text"
          field={@changeset[:knowledge_base_link]}
          placeholder="Knowledge Base URL"
          maxlength="255"
        />
      </div>

      <div class="form-group mb-0">
        <%= if @display_labels do %>
          <label for="publisher_support_email">Support Email</label>
        <% end %>
        <.input
          id="publisher_support_email"
          class="form-control"
          type="text"
          field={@changeset[:support_email]}
          placeholder="Support Email"
          maxlength="255"
        />
      </div>

      <button class="form-button btn btn-md btn-primary btn-block mt-3" type="submit">Save</button>
    </.form>
    """
  end
end
