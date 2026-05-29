defmodule Oli.Scenarios.Directives.ObjectivesHandler do
  @moduledoc """
  Handles authoring-time learning objective operations for scenario projects.
  """

  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, ObjectivesDirective}

  def handle(%ObjectivesDirective{project: project_name, ops: ops}, %ExecutionState{} = state) do
    with {:ok, author} <- validate_author(state.current_author),
         {:ok, built_project} <- get_project(state, project_name),
         {:ok, updated_project} <- apply_ops(built_project, author, ops || []) do
      {:ok, %{state | projects: Map.put(state.projects, project_name, updated_project)}}
    else
      {:error, reason} -> {:error, "Failed to apply objective operations: #{reason}"}
    end
  end

  defp validate_author(nil), do: {:error, "No author available"}
  defp validate_author(author), do: {:ok, author}

  defp get_project(_state, nil), do: {:error, "Project name is required"}

  defp get_project(%ExecutionState{} = state, project_name) do
    case Map.get(state.projects, project_name) do
      nil -> {:error, "Project '#{project_name}' not found"}
      built_project -> {:ok, built_project}
    end
  end

  defp apply_ops(built_project, author, ops) when is_list(ops) do
    Enum.reduce_while(ops, {:ok, built_project}, fn op, {:ok, acc} ->
      case apply_op(acc, author, op) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp apply_ops(_built_project, _author, _ops), do: {:error, "ops must be a list"}

  defp apply_op(built_project, author, %{"create" => %{"title" => title}}) do
    case ObjectiveEditor.add_new(%{title: title}, author, built_project.project) do
      {:ok, %{revision: revision}} ->
        {:ok, put_objective(built_project, title, revision)}

      {:error, reason} ->
        {:error, "Could not create objective '#{title}': #{inspect(reason)}"}
    end
  end

  defp apply_op(
         built_project,
         author,
         %{"create_sub" => %{"parent" => parent_title, "title" => title}}
       ) do
    with {:ok, parent} <- get_objective(built_project, parent_title),
         {:ok, %{revision: child, container: updated_parent}} <-
           ObjectiveEditor.add_new(%{title: title}, author, built_project.project, parent.slug) do
      {:ok,
       built_project
       |> put_objective(parent_title, updated_parent)
       |> put_objective(title, child)}
    else
      {:error, reason} ->
        {:error, "Could not create sub-objective '#{title}': #{inspect(reason)}"}
    end
  end

  defp apply_op(
         built_project,
         author,
         %{"remove_sub" => %{"parent" => parent_title, "title" => title}}
       ) do
    with {:ok, parent} <- get_objective(built_project, parent_title),
         {:ok, child} <- get_objective(built_project, title),
         :ok <- validate_child(parent, child),
         {:ok, updated_parent} <-
           ObjectiveEditor.remove_sub_objective_from_parent(
             child.slug,
             author,
             built_project.project,
             parent
           ) do
      {:ok, put_objective(built_project, parent_title, updated_parent)}
    else
      {:error, reason} ->
        {:error, "Could not remove sub-objective '#{title}': #{inspect(reason)}"}
    end
  end

  defp apply_op(_built_project, _author, op) do
    {:error,
     "Unsupported objective operation #{inspect(op)}. Expected create, create_sub, or remove_sub"}
  end

  defp get_objective(built_project, title) do
    case Map.get(built_project.objectives_by_title || %{}, title) do
      nil -> {:error, "Objective '#{title}' not found"}
      revision -> {:ok, revision}
    end
  end

  defp validate_child(parent, child) do
    if child.resource_id in (parent.children || []) do
      :ok
    else
      {:error, "Objective '#{child.title}' is not a sub-objective of '#{parent.title}'"}
    end
  end

  defp put_objective(built_project, title, revision) do
    %{
      built_project
      | objectives_by_title: Map.put(built_project.objectives_by_title || %{}, title, revision)
    }
  end
end
