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
          <.input
            type="checkbox"
            field={@changeset[:registration_open]}
            label="Registration open"
            class="form-check-input"
          />
        </div>

        <div class="form-check">
          <.input
            type="checkbox"
            field={@changeset[:requires_enrollment]}
            label="Requires enrollment"
            class="form-check-input"
          />
        </div>

        <div class="form-check">
          <.input
            type="checkbox"
            field={@changeset[:skip_email_verification]}
            label="Omit student email verification"
            class="form-check-input"
          />
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
