defmodule OliWeb.Sections.OpenFreeSettings do
  use OliWeb, :surface_component

  alias Surface.Components.Field
  alias Surface.Components.Form.{Field, Label, Checkbox}
  alias OliWeb.Common.Properties.Group
  import Ecto.Changeset

  prop(changeset, :any, required: true)
  prop(disabled, :boolean, required: true)
  prop(is_admin, :boolean, required: true)
  prop(ctx, :struct, required: true)

  def render(assigns) do
    ~F"""
    <Group label="Direct Delivery" description="Direct Delivery section settings">
      <Field name={:registration_open} class="form-check">
        <Checkbox class="form-check-input" value={get_field(@changeset, :registration_open)}/>
        <Label class="form-check-label"/>
      </Field>

      <Field name={:requires_enrollment} class="mt-2 form-check">
        <Checkbox class="form-check-input" value={get_field(@changeset, :requires_enrollment)}/>
        <Label class="form-check-label"/>
      </Field>

      <Field name={:skip_email_verification} class="mt-2 form-check">
        <Checkbox class="form-check-input" value={get_field(@changeset, :skip_email_verification)}/>
        <Label class="form-check-label">Omit student email verification</Label>
      </Field>

      <div class="form-row">
        <small class="text-nowrap form-text text-muted">
          Timezone: {@ctx.local_tz}
        </small>
      </div>

      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </Group>
    """
  end
end
