defmodule OliWeb.Sections.ContentSettings do
  use Surface.Component

  alias Surface.Components.Form.{
    Field,
    Label,
    Checkbox,
  }

  alias OliWeb.Common.Properties.{Group}
  import Ecto.Changeset

  prop changeset, :any, required: true
  prop save, :string, default: "save"

  def render(assigns) do
    ~F"""
    <Group label="Content Settings" description="Settings related to the course content">
        <Field name={:display_curriculum_item_numbering} class="form-check">
          <Checkbox class="form-check-input" value={get_field(@changeset, :display_curriculum_item_numbering)}/>
          <Label class="form-check-label">Display curriculum item numbers</Label>
        </Field>
      <div class="text-muted">Enable students to see the curriculum's module and unit numbers</div>
      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </Group>
    """
  end
end
