defmodule OliWeb.Sections.MainDetails do
  use OliWeb, :html

  import Ecto.Changeset

  attr(:changeset, :any, required: true)
  attr(:disabled, :boolean, required: true)
  attr(:is_admin, :boolean, required: true)
  attr(:brands, :list, required: true)
  attr(:institutions, :list, required: true)

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
