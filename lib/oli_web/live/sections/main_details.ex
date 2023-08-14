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
        <div class="flex justify-between">
          <label for="section_title">Title</label>
          <.error :for={error <- Keyword.get_values(@changeset.errors || [], :title)}>
            <%= translate_error(error) %>
          </.error>
        </div>
        <.input
          id="section_title"
          name="section[title]"
          value={get_field(@changeset, :title)}
          class="form-control"
          disabled={@disabled}
        />
      </div>
      <div class="form-label-group">
        <div class="flex justify-between">
          <label for="section_description">Description</label>
          <.error :for={error <- Keyword.get_values(@changeset.errors || [], :description)}>
            <%= translate_error(error) %>
          </.error>
        </div>
        <.input
          id="section_description"
          name="section[description]"
          value={get_field(@changeset, :description)}
          class="form-control"
          disabled={@disabled}
        />
      </div>
      <div class="mt-2">
        <label for="section_brand_id">Brand</label>
        <.input
          id="section_brand_id"
          type="select"
          class="form-control"
          name="section[brand_id]"
          value={get_field(@changeset, :brand_id)}
          options={[{"None", nil} | @brands]}
        />
      </div>
      <div class="mt-2">
        <label for="section_institution_id">Institution</label>
        <.input
          id="section_institution_id"
          type="select"
          class="form-control"
          name="section[institution_id]"
          value={get_field(@changeset, :institution_id)}
          options={[{"None", nil} | @institutions]}
          disabled={get_field(@changeset, :lti_1p3_deployment_id) != nil}
        />
      </div>

      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </div>
    """
  end
end
