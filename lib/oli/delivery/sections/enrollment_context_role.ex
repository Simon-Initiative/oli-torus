defmodule Oli.Delivery.Sections.EnrollmentContextRole do
  use Ecto.Schema

  schema "enrollments_context_roles" do
    belongs_to :enrollment, Oli.Delivery.Sections.Enrollment
    belongs_to :context_role, Lti_1p3.DataProviders.EctoProvider.ContextRole
  end
end
