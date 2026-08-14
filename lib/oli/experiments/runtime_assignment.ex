defmodule Oli.Experiments.RuntimeAssignment do
  @moduledoc """
  Coordinates single and page-batched delivery assignment operations.
  """

  alias Oli.Experiments.{ExperimentError, Scope}
  alias Oli.Repo

  @doc false
  def assign_condition(request, deps) do
    metadata = assignment_metadata(request)
    start_time = System.monotonic_time()

    :telemetry.execute(
      [:oli, :experiments, :assignment, :start],
      %{system_time: System.system_time()},
      metadata
    )

    try do
      result =
        Repo.transaction(fn -> deps.assign.(request) end)
        |> case do
          {:ok, result} -> result
          {:error, %ExperimentError{} = error} -> {:error, error}
        end

      :telemetry.execute(
        [:oli, :experiments, :assignment, :stop],
        %{duration: System.monotonic_time() - start_time},
        metadata
      )

      result
    rescue
      exception ->
        :telemetry.execute(
          [:oli, :experiments, :assignment, :exception],
          %{duration: System.monotonic_time() - start_time},
          Map.merge(metadata, %{kind: :error, reason: exception.__struct__})
        )

        reraise exception, __STACKTRACE__
    end
  end

  @doc false
  def assigned_condition(request, deps) do
    with {:ok, scope} <- deps.validate_scope.(request.scope),
         :ok <- deps.require_delivery.(scope),
         :ok <- deps.require_placement.(request),
         {:ok, _revision} <- deps.resolve_revision.(request, scope),
         {:ok, decision} <- deps.existing_assignment.(request, scope) do
      {:ok, decision}
    end
  end

  @doc false
  def assign_page_conditions(requests, deps) do
    with {:ok, scope} <- deps.common_scope.(requests),
         :ok <- deps.require_delivery.(scope),
         {:ok, scope} <- deps.validate_publication.(scope) do
      Repo.transaction(fn -> deps.batch_assign.(requests, scope) end)
      |> case do
        {:ok, {decisions, events}} ->
          Enum.each(events, deps.emit_committed)
          {:ok, decisions}

        {:error, %ExperimentError{} = error} ->
          {:error, error}
      end
    end
  end

  defp assignment_metadata(request) do
    scope = request.scope || %Scope{}

    %{
      institution_id: scope.institution_id,
      project_id: scope.project_id,
      publication_id: scope.publication_id,
      section_id: scope.section_id,
      user_id: scope.user_id,
      enrollment_id: scope.enrollment_id,
      alternatives_resource_id: request.alternatives_resource_id,
      alternatives_revision_id: request.alternatives_revision_id,
      page_resource_id: request.page_resource_id,
      content_element_id: request.content_element_id
    }
  end
end
