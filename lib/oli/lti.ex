defmodule Oli.Lti do
  @moduledoc """
  The Lti context.
  """
  def parse_lti_role(roles) do
    cond do
      String.contains?(roles, "Learner") ->
        { :student}
      String.contains?(roles, "Instructor") ->
        { :instructor}
      String.contains?(roles, "Administrator") ->
        { :administrator}
    end
  end
end
