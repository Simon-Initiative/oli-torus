defmodule OliWeb.Products.Details.Edit do
  use OliWeb, :html

  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers

  alias OliWeb.Components.Common

  defp statuses do
    [{"Active", "active"}, {"Archived", "archived"}]
  end

  attr(:product, :any, default: nil)
  attr(:changeset, :any, default: nil)
  attr(:available_brands, :any, default: nil)
  attr(:publishers, :list, required: true)
  attr(:is_admin, :boolean)
  attr(:project_slug, :string, required: true)
  attr(:ctx, :map, required: true)

  def render(assigns) do
    ~H"""
    <div>
      <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" action="#">
        <div class="form-group mb-2">
          {label(f, :title)}
          {text_input(f, :title, class: "form-control")}
          <div>{error_tag(f, :title)}</div>
        </div>

        <div class="form-group mb-2">
          {label(f, :status)}
          {select(f, :status, statuses(),
            class: "form-control " <> error_class(f, :status, "is-invalid"),
            autofocus: focusHelper(f, :status)
          )}
          <div>{error_tag(f, :status)}</div>
        </div>

        <div class="form-group mb-2">
          {label(f, :description)}
          {text_input(f, :description, class: "form-control")}
          <div>{error_tag(f, :description)}</div>
        </div>

        <% welcome_title =
          (Common.fetch_field(f.source, :welcome_title) &&
             Common.fetch_field(f.source, :welcome_title)["children"]) || [] %>
        <Common.rich_text_editor_field
          id="welcome_title_field"
          form={f}
          value={welcome_title}
          field_name={:welcome_title}
          field_label="Welcome Message Title"
          on_edit="welcome_title_change"
          project_slug={@project_slug}
          ctx={@ctx}
        />

        <div class="form-group mb-2">
          {label(f, :encouraging_subtitle, "Encouraging Subtitle", class: "control-label")}

          {textarea(f, :encouraging_subtitle,
            class: "form-control",
            placeholder: "Enter a subtitle to encourage students to begin the course...",
            required: false
          )}
          <div>{error_tag(f, :encouraging_subtitle)}</div>
        </div>

        <div class="form-group mb-2">
          {label(f, :publisher_id, "Template Publisher")}
          {select(f, :publisher_id, Enum.map(@publishers, &{&1.name, &1.id}),
            class: "form-control " <> error_class(f, :publisher_id, "is-invalid"),
            autofocus: focusHelper(f, :publisher_id),
            required: true
          )}
          <div>{error_tag(f, :publisher_id)}</div>
        </div>

        {submit("Save", class: "btn btn-primary")}
      </.form>
    </div>
    """
  end
end
