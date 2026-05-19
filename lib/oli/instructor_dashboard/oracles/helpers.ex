defmodule Oli.InstructorDashboard.Oracles.Helpers do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.Scope
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Repo
  alias Lti_1p3.Roles.ContextRoles

  @learner_role_id ContextRoles.get_role(:context_learner).id

  @spec section_scope(OracleContext.t()) :: {:ok, pos_integer(), Scope.t()} | {:error, term()}
  def section_scope(%OracleContext{
        dashboard_context_type: :section,
        dashboard_context_id: section_id,
        scope: %Scope{} = scope
      }),
      do: {:ok, section_id, scope}

  def section_scope(%OracleContext{dashboard_context_type: type}),
    do: {:error, {:invalid_dashboard_context_type, type}}

  @spec enrolled_learner_ids(pos_integer()) :: [pos_integer()]
  def enrolled_learner_ids(section_id) do
    from(e in Enrollment,
      join: ecr in assoc(e, :context_roles),
      where:
        e.section_id == ^section_id and e.status == :enrolled and ecr.id == ^@learner_role_id,
      select: e.user_id,
      distinct: true
    )
    |> Repo.all()
    |> Enum.sort()
  end

  @spec learner_role_id() :: pos_integer()
  def learner_role_id, do: @learner_role_id

  @spec section(pos_integer()) :: Section.t()
  def section(section_id), do: Sections.get_section!(section_id)
end
