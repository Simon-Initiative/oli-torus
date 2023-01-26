defmodule OliWeb.Sections.LtiSettings do
  use Surface.Component

  alias OliWeb.Common.Properties.{Group, ReadOnly}
  import OliWeb.Common.Properties.Utils

  prop section, :any, required: true

  def render(assigns) do
    ~F"""
    <Group
      label="LTI Settings"
      description="Settings defined in the LMS that is launching students and instructors into this course section"
    >
      <ReadOnly label="Context ID" value={@section.context_id} />
      <ReadOnly label="Grade Passback Enabled" value={boolean(@section.grade_passback_enabled)} />
      <ReadOnly label="Line Items Service URL" value={@section.line_items_service_url} />
      <ReadOnly
        label="Names and Role Provisioning Service Enabled"
        value={boolean(@section.nrps_enabled)}
      />
      <ReadOnly
        label="Names and Role Provisioning Service URL"
        value={@section.nrps_context_memberships_url}
      />
    </Group>
    """
  end
end
