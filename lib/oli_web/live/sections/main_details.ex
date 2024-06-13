defmodule OliWeb.Sections.MainDetails do
  use OliWeb, :html

  alias OliWeb.Common.React
  alias OliWeb.Components.Common

  attr(:changeset, :any, required: true)
  attr(:form, :any, required: true)
  attr(:disabled, :boolean, required: true)
  attr(:is_admin, :boolean, required: true)
  attr(:brands, :list, required: true)
  attr(:institutions, :list, required: true)
  attr(:project_slug, :string, required: true)
  attr(:ctx, :map, required: true)

  def render(assigns) do
    ~H"""
    <div>
      <div class="form-label-group">
        <.input field={@changeset[:title]} label="Title" class="form-control" disabled={@disabled} />
      </div>
      <div class="form-label-group">
        <.input
          field={@changeset[:description]}
          label="Description"
          class="form-control"
          disabled={@disabled}
        />
      </div>

      <.welcome_message_editor form={@form} project_slug={@project_slug} ctx={@ctx} />

      <div class="form-label-group">
        <.input
          field={@changeset[:encouraging_subtitle]}
          label="Encouraging Subtitle"
          class="form-control"
          disabled={@disabled}
        />
      </div>
      <div class="mt-2">
        <.input
          type="select"
          field={@changeset[:brand_id]}
          label="Brand"
          class="form-control"
          options={[{"None", nil} | @brands]}
        />
      </div>
      <div class="mt-2">
        <.input
          type="select"
          field={@changeset[:institution_id]}
          label="Institution"
          class="form-control"
          options={[{"None", nil} | @institutions]}
          disabled={@changeset[:lti_1p3_deployment_id].value != nil}
        />
      </div>

      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :project_slug, :string, required: true
  attr :ctx, :map, required: true

  defp welcome_message_editor(assigns) do
    ~H"""
    <% welcome_title =
      (Common.fetch_field(@form.source, :welcome_title) &&
         Common.fetch_field(@form.source, :welcome_title)["children"]) || [] %>
    <div id="welcome_title_field" class="form-label-group mb-3">
      <%= label(@form, :welcome_title, "Welcome Message Title", class: "control-label") %>
      <%= hidden_input(@form, :welcome_title) %>

      <div id="welcome_title_editor" phx-update="ignore">
        <%= React.component(
          @ctx,
          "Components.RichTextEditor",
          %{
            projectSlug: @project_slug,
            onEdit: "initial_function_that_will_be_overwritten",
            onEditEvent: "welcome_title_change",
            onEditTarget: "#welcome_title_field",
            editMode: true,
            value: welcome_title,
            fixedToolbar: true,
            allowBlockElements: false
          },
          id: "rich_text_editor_react_component"
        ) %>
      </div>
    </div>
    """
  end
end
