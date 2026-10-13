defmodule Oli.Delivery.SecureAssessments do
  @moduledoc """
  Instance capability for the secure-delivery assessment policy.

  This foundation stores policy but does not enforce secure launches. Instructor
  controls remain unavailable until session enforcement and launch admission land.
  """

  @doc "Returns the runtime instance capability, disabled by default."
  @spec supported?() :: boolean()
  def supported?, do: Application.get_env(:oli, :supports_secure_delivery, false) == true

  @doc "Requires both instance support and server-configured enforcement readiness for instructor controls."
  @spec settings_available?() :: boolean()
  def settings_available? do
    supported?() and Application.get_env(:oli, :secure_delivery_enforcement_ready, false) == true
  end
end
