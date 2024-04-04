defmodule Oli.Deployment do

  def mode() do
    Application.get_env(:oli, :deployment_mode, :both)
  end

  def has_application?() do
    mode() in [:application_and_analytics, :application]
  end

  def has_analytics?() do
    mode() in [:application_and_analytics, :analytics]
  end

end
