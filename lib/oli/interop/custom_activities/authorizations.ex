defmodule Oli.Interop.CustomActivities.Authorizations do
  alias Lti_1p3.Roles.ContextRoles

  import XmlBuilder

  def setup(%{
        context: context
      }) do
    element(
      :authorizations,
      %{
        grade_responses:
          ContextRoles.contains_role?(
            context.enrollment.context_roles,
            ContextRoles.get_role(:context_instructor)
          ),
        instruct_material:
          ContextRoles.contains_role?(
            context.enrollment.context_roles,
            ContextRoles.get_role(:context_instructor)
          ),
        view_material: "true",
        view_responses: "true"
      }
    )
  end
end
