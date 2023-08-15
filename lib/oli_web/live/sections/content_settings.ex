defmodule OliWeb.Sections.ContentSettings do
  use OliWeb, :html

  alias OliWeb.Common.Properties.Group

  attr :changeset, :any, required: true

  def render(assigns) do
    ~H"""
    <Group.render label="Content Settings" description="Settings related to the course content">
      <div class="form-check">
        <.input
          field={@changeset[:display_curriculum_item_numbering]}
          type="checkbox"
          class="form-check-input"
          label="Display curriculum item numbers"
        />
      </div>
      <div class="text-muted">Enable students to see the curriculum's module and unit numbers</div>
      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </Group.render>
    """
  end
end
