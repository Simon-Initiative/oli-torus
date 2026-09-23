defmodule OliWeb.Api.AssessmentDependencyController do
  @moduledoc "Transport for authorized, attempt-owned shared-state dependencies."
  use OliWeb, :controller
  alias Oli.Delivery.SecureAssessments.Dependencies

  @doc "Reads only namespaces from the server-owned pinned manifest."
  def read(conn, %{"resource_attempt_guid" => guid} = params) do
    respond(conn, Dependencies.read_shared(guid, conn.assigns.current_user, params["keys"]))
  end

  @doc "Updates this attempt's shared snapshot, never global learner state."
  def write(conn, %{"resource_attempt_guid" => guid, "updates" => updates}) do
    respond(conn, Dependencies.write_shared(guid, conn.assigns.current_user, updates))
  end

  def write(conn, _), do: OliWeb.Plugs.SecureAssessment.deny(conn, :invalid_batch)

  defp respond(conn, {:ok, values}), do: json(conn, values)
  defp respond(conn, {:error, reason}), do: OliWeb.Plugs.SecureAssessment.deny(conn, reason)
end
