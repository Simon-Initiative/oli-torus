defmodule Oli.Interop.CustomActivities.Authorizations do
  alias Oli.Delivery.Sections

  import XmlBuilder

  def setup(%{
        context: context
      }) do
    element(
      :authorizations,
      %{
        grade_responses: Sections.contains_instructor_role?(context.enrollment.context_roles),
        instruct_material: Sections.contains_instructor_role?(context.enrollment.context_roles),
        view_material: "true",
        view_responses: "true"
      }
    )
  end
end
