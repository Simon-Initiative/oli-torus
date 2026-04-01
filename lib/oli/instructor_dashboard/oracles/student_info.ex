defmodule Oli.InstructorDashboard.Oracles.StudentInfo do
  @moduledoc """
  Returns enrolled learner identity rows for drilldown UX.
  """

  use Oli.Dashboard.Oracle

  import Ecto.Query, warn: false

  alias Oli.Dashboard.OracleContext
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.InstructorDashboard.Oracles.Helpers
  alias Oli.Repo

  @impl true
  def key, do: :oracle_instructor_student_info

  @impl true
  def version, do: 1

  @impl true
  def load(%OracleContext{} = context, _opts) do
    with {:ok, section_id, _scope} <- Helpers.section_scope(context) do
      {:ok, rows(section_id)}
    end
  end

  defp rows(section_id) do
    learner_role_id = Helpers.learner_role_id()

    from(e in Enrollment,
      join: ecr in assoc(e, :context_roles),
      join: u in assoc(e, :user),
      where: e.section_id == ^section_id and e.status == :enrolled and ecr.id == ^learner_role_id,
      distinct: u.id,
      order_by: u.id,
      select: %{
        student_id: u.id,
        email: u.email,
        given_name: u.given_name,
        family_name: u.family_name,
        picture: u.picture,
        last_interaction_at: e.updated_at
      }
    )
    |> Repo.all()
  end
end
