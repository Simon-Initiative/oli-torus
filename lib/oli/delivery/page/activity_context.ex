defmodule Oli.Delivery.Page.ActivityContext do
  @moduledoc """
  Defines the context required to render an activity in delivery mode.
  """
  use Appsignal.Instrumentation.Decorators

  alias Oli.Delivery.Page.ModelPruner
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Delivery.Attempts.Core.ActivityAttempt
  alias Oli.Delivery.Attempts.Core
  alias Oli.Activities.State
  alias Oli.Activities.State.ActivityState
  alias Oli.Activities
  alias Phoenix.HTML

  @doc """
  Creates a mapping of activity id to an `%ActivitySummary` struct, based
  off of the supplied list of activity ids and a map of resource ids to
  resolved revisions.
  """
  @spec create_context_map(
          boolean(),
          %{},
          %Oli.Delivery.Attempts.Core.ResourceAttempt{},
          %Oli.Resources.Revision{},
          %Oli.Delivery.Settings.Combined{}
        ) :: %{}
  @decorate transaction_event()
  def create_context_map(
        graded,
        latest_attempts,
        resource_attempt,
        page_revision,
        effective_settings,
        opts \\ []
      ) do
    # get a view of all current registered activity types
    registrations = Activities.list_activity_registrations()
    reg_map = Enum.reduce(registrations, %{}, fn r, m -> Map.put(m, r.id, r) end)

    activity_states =
      State.from_attempts(latest_attempts, resource_attempt, page_revision, effective_settings)

    ordinal_assign_fn = create_ordinal_assignment_fn(graded, opts)

    Enum.map(latest_attempts, fn {id,
                                  {%ActivityAttempt{revision: revision} = activity_attempt, _}} ->
      model = Core.select_model(activity_attempt)

      # the activity type this revision pertains to
      type = Map.get(reg_map, revision.activity_type_id)

      state =
        Map.get(activity_states, id)
        |> prune_feedback_from_state(Keyword.get(opts, :show_feedback, true))

      {id,
       %ActivitySummary{
         id: id,
         attempt_guid: state.attemptGuid,
         unencoded_model: model,
         model: prepare_model(model, opts),
         state: prepare_state(state),
         lifecycle_state: state.lifecycle_state,
         delivery_element: type.delivery_element,
         authoring_element: type.authoring_element,
         script: type.delivery_script,
         graded: graded,
         bib_refs: Map.get(model, "bibrefs", []),
         ordinal: ordinal_assign_fn.(id),
         variables: build_variables_map(type.variables, type.petite_label)
       }}
    end)
    |> Map.new()
  end

  def build_variables_map(variables, petite_label) do
    whitelist_prefix = "ACTIVITY_" <> String.upcase(petite_label) <> "_"

    Enum.reduce(variables, %{}, fn variable_name, acc ->
      if String.starts_with?(variable_name, whitelist_prefix) do
        Map.put(acc, variable_name, System.get_env(variable_name, ""))
      else
        acc
      end
    end)
  end

  defp prune_feedback_from_state(state, true), do: state

  defp prune_feedback_from_state(state, false) do
    %Oli.Activities.State.ActivityState{
      state
      | parts: prune_feedback_from_parts(state.parts),
        score: nil,
        outOf: nil
    }
  end

  defp prune_feedback_from_parts(parts) do
    Enum.map(parts, fn part ->
      %Oli.Activities.State.PartState{part | feedback: nil}
    end)
  end

  defp create_ordinal_assignment_fn(false, _), do: fn _ -> nil end

  defp create_ordinal_assignment_fn(true, opts) do
    case Keyword.has_key?(opts, :assign_ordinals_from) do
      true ->
        {map, _} =
          Keyword.get(opts, :assign_ordinals_from)
          |> Oli.Resources.PageContent.flat_filter(fn e -> e["type"] == "activity-reference" end)
          |> Enum.reduce({%{}, 1}, fn e, {m, ordinal} ->
            {Map.put(m, e["activity_id"], ordinal), ordinal + 1}
          end)

        fn activity_id ->
          Map.get(map, activity_id)
        end

      false ->
        fn _ -> nil end
    end
  end

  @doc """
  Takes a full context map produced by create_context_map/2 and 'thins' it out to
  leave only the id, the delivery element name and the attempt guid. This is to allow
  a page implementation that wishes to avoid injecting a potentially large number of
  activities (and their full state and model) into a server rendered document.
  """
  def to_thin_context_map(context_map) do
    Enum.map(context_map, fn {k,
                              %{
                                id: id,
                                attempt_guid: attempt_guid,
                                delivery_element: delivery_element
                              }} ->
      {k,
       %{
         id: id,
         attemptGuid: attempt_guid,
         deliveryElement: delivery_element
       }}
    end)
    |> Map.new()
  end

  def prepare_model(model, opts \\ []) do
    model = if Keyword.get(opts, :prune, true), do: ModelPruner.prune(model), else: model

    case Jason.encode(model) do
      {:ok, s} -> s |> encode()
      {:error, _} -> "{ \"error\": true }" |> encode()
    end
  end

  def prepare_state(%ActivityState{} = state) do
    case Jason.encode(state) do
      {:ok, s} -> s |> encode()
      {:error, _} -> "{ \"error\": true }" |> encode()
    end
  end

  def encode(s) do
    {:safe, encoded} = HTML.html_escape(s)
    IO.iodata_to_binary(encoded)
  end
end
