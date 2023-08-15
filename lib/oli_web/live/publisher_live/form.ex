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
        <.input
          id="publisher_email"
          class="form-control"
          type="text"
          field={@changeset[:email]}
          label={if @display_labels, do: "Publisher Email"}
          placeholder="Email"
          maxlength="255"
        />
      </div>

      <.input
        id="publisher_address"
        class="form-control"
        type="text"
        field={@changeset[:address]}
        label={if @display_labels, do: "Publisher Address"}
        placeholder="Address"
        maxlength="255"
      />

      <.input
        id="publisher_main_contact"
        class="form-control"
        type="text"
        field={@changeset[:main_contact]}
        label={if @display_labels, do: "Publisher Main Contact"}
        placeholder="Main Contact"
        maxlength="255"
      />

      <.input
        id="publisher_website_url"
        class="form-control"
        type="text"
        field={@changeset[:website_url]}
        label={if @display_labels, do: "Publisher Website URL"}
        placeholder="Website URL"
        maxlength="255"
      />

      <button class="form-button btn btn-md btn-primary btn-block mt-3" type="submit">Save</button>
    </.form>
    """
  end
end
