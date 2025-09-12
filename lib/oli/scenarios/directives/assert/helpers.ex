defmodule Oli.Scenarios.Directives.Assert.Helpers do
  @moduledoc """
  Common helper functions shared across assertion directives.
  """

  alias Oli.Scenarios.Engine

  @doc """
  Gets a section from state by name.
  """
  def get_section(state, section_name) do
    case Engine.get_section(state, section_name) do
      nil -> {:error, "Section '#{section_name}' not found"}
      section -> {:ok, section}
    end
  end

  @doc """
  Gets a project from state by name.
  """
  def get_project(state, project_name) do
    case Engine.get_project(state, project_name) do
      nil -> {:error, "Project '#{project_name}' not found"}
      project -> {:ok, project}
    end
  end

  @doc """
  Gets a user from state by name.
  """
  def get_user(state, user_name) do
    case Engine.get_user(state, user_name) do
      nil -> {:error, "User '#{user_name}' not found"}
      user -> {:ok, user}
    end
  end

  @doc """
  Formats a value for display in assertion messages.
  """
  def format_value(nil), do: "nil"
  def format_value(value) when is_float(value), do: Float.round(value, 2) |> to_string()
  def format_value(value), do: to_string(value)
end
