defmodule OliWeb.Sections.OpenFreeSettings do
  use OliWeb, :html

  alias OliWeb.Common.Properties.Group
  import Ecto.Changeset

  attr(:changeset, :any, required: true)
  attr(:disabled, :boolean, required: true)
  attr(:is_admin, :boolean, required: true)
  attr(:ctx, :map, required: true)

  def render(assigns) do
    ~H"""
    <div>
      <Group.render label="Direct Delivery" description="Direct Delivery section settings">
        <div class="form-check">
          <input
            id="registration_open"
            type="checkbox"
            name="section[registration_open]"
            class="form-check-input"
            checked={get_field(@changeset, :registration_open)}
          />
          <label for="registration_open" class="form-check-label">Registration open</label>
        </div>

        <div class="form-check">
          <input
            id="requires_enrollment"
            type="checkbox"
            name="section[requires_enrollment]"
            class="form-check-input"
            checked={get_field(@changeset, :requires_enrollment)}
          />
          <label for="registration_open" class="form-check-label">Requires enrollment</label>
        </div>

        <div class="form-check">
          <input
            id="skip_email_verification"
            type="checkbox"
            name="section[skip_email_verification]"
            class="form-check-input"
            checked={get_field(@changeset, :skip_email_verification)}
          />
          <label for="skip_email_verification" class="form-check-label">
            Omit student email verification
          </label>
        </div>

        <div class="form-row">
          <small class="text-nowrap form-text text-muted">
            Timezone: <%= @ctx.local_tz %>
          </small>
        </div>

        <button class="btn btn-primary mt-3" type="submit">Save</button>
      </Group.render>
    </div>
    """
  end
end
