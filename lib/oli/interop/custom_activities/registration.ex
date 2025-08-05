defmodule Oli.Interop.CustomActivities.Registration do
  import XmlBuilder

  def setup(%{
        context: context
      }) do
    element(
      :registration,
      %{
        date_created: DateTime.to_unix(context.enrollment.inserted_at),
        guid: context.enrollment.id,
        role: Oli.Delivery.Sections.contains_instructor_role?(context.enrollment.context_roles),
        section_guid: context.section.slug,
        status: "valid",
        user_guid: context.user.email
      }
    )
  end
end
