defmodule Oli.Interop.CustomActivities.Registration do
  alias Lti_1p3.Roles.ContextRoles

  import XmlBuilder

  def setup(%{
        context: context
      }) do
    element(
      :registration,
      %{
        date_created: DateTime.to_unix(context.enrollment.inserted_at),
        guid: context.enrollment.id,
        role:
          ContextRoles.contains_role?(
            context.enrollment.context_roles,
            ContextRoles.get_role(:context_instructor)
          ),
        section_guid: context.section.slug,
        status: "valid",
        user_guid: context.user.email
      }
    )
  end
end
