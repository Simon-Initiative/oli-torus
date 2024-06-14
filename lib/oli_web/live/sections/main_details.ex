defmodule OliWeb.Sections.MainDetails do
  use OliWeb, :html

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

      <% welcome_title =
        (Common.fetch_field(@form.source, :welcome_title) &&
           Common.fetch_field(@form.source, :welcome_title)["children"]) || [] %>
      <Common.rich_text_editor_field
        id="welcome_title_field"
        form={@form}
        value={welcome_title}
        field_name={:welcome_title}
        field_label="Welcome Message Title"
        on_edit="welcome_title_change"
        project_slug={@project_slug}
        ctx={@ctx}
      />
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
end
