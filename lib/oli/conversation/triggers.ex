defmodule Oli.Conversation.Triggers do
  require Logger
  import Ecto.Query
  alias Oli.Repo
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, ResourceAccess}
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Phoenix.PubSub
  alias Oli.Conversation.Trigger
  alias Oli.Conversation.AdaptiveTriggerInvocationCache
  alias Oli.Activities.Model.{Part}
  alias Oli.Publishing.PublishedResource
  alias Oli.Resources.Revision

  # The supported trigger type
  @trigger_types [
    :page,
    :adaptive_page,
    :adaptive_component,
    :content_group,
    :content_block,
    :correct_answer,
    :incorrect_answer,
    :hint,
    :explanation,
    :targeted_feedback
  ]

  def trigger_types(), do: @trigger_types

  def evaluation_triggers(),
    do: [:correct_answer, :incorrect_answer, :explanation, :targeted_feedback]

  # Given a trigger type and trigger type specific data, formulate an agent readable description
  # that we will use in creating the entire prompt.
  def description(:page, _), do: "Visited the learning page"

  def description(:adaptive_page, data),
    do: "Viewed an adaptive lesson screen activation point (id: #{sanitize_component_id(data)})"

  def description(:adaptive_component, data),
    do:
      "Activated an adaptive component trigger (type: #{sanitize_component_type(data)}, id: #{sanitize_component_id(data)})"

  def description(:content_group, data),
    do: "Clicked a button next to a content group id (id: #{data["ref_id"]})"

  def description(:content_block, data), do: "Viewed a content block (id: #{data["ref_id"]})"

  def description(:correct_answer, data),
    do:
      "Answered correctly part #{data["part_id"]} of question #{data["question"]}. The student's response is in: #{data["student_response"]}"

  def description(:incorrect_answer, data),
    do:
      "Answered incorrectly part #{data["part_id"]} of question #{data["question"]}. The student's response is in: #{data["student_response"]}"

  def description(:hint, data),
    do:
      "Requested a hint (id: #{data["ref_id"]}) for part #{data["part_id"]} of question #{data["question"]}"

  def description(:explanation, data),
    do:
      "Received the explanation (id: #{data["ref_id"]}) for part #{data["part_id"]} of question #{data["question"]}"

  def description(:targeted_feedback, data),
    do:
      "Received targeted feedback (id: #{data["ref_id"]}) for part #{data["part_id"]} of question #{data["question"]}. The student's response is in: #{data["student_response"]}"

  @adaptive_component_types MapSet.new([
                              "janus-ai-trigger",
                              "janus-image",
                              "janus-navigation-button"
                            ])
  @adaptive_page_component_type "janus-ai-trigger"
  @adaptive_trigger_cooldown_ms :timer.seconds(30)
  @adaptive_prompt_max_length 2_000

  defp sanitize_component_type(data) when is_map(data) do
    case Map.get(data, "component_type") do
      value when is_binary(value) ->
        case MapSet.member?(@adaptive_component_types, value) do
          true -> value
          false -> "component"
        end

      _ ->
        "component"
    end
  end

  defp sanitize_component_type(_), do: "component"

  defp sanitize_component_id(data) when is_map(data) do
    data
    |> Map.get("component_id")
    |> normalize_component_id("unknown")
  end

  defp sanitize_component_id(_), do: "unknown"

  defp normalize_component_id(value, fallback) when is_binary(value) do
    value
    |> String.replace(~r/[[:cntrl:]]/u, "")
    |> String.replace(~r/[^A-Za-z0-9:_-]/u, "")
    |> String.slice(0, 100)
    |> case do
      "" -> fallback
      sanitized -> sanitized
    end
  end

  defp normalize_component_id(_, fallback), do: fallback

  @doc """
  Verify that the user is enrolled in a section with
  with the AI agent and triggers enabled.
  """
  def verify_access(section_slug, user_id) do
    if is_nil(user_id) or is_nil(section_slug) do
      {:error, :no_access}
    else
      case Oli.Accounts.User
           |> join(:left, [u], e in Oli.Delivery.Sections.Enrollment, on: u.id == e.user_id)
           |> join(:left, [_, e], s in Oli.Delivery.Sections.Section, on: s.id == e.section_id)
           |> where(
             [_, e, s],
             s.slug == ^section_slug and s.triggers_enabled == true and
               s.assistant_enabled == true and
               e.user_id == ^user_id
           )
           |> select([_, _, s], s)
           |> limit(1)
           |> Repo.one() do
        nil -> {:error, :no_access}
        section -> {:ok, section}
      end
    end
  end

  @doc """
  Parse and validate a client-provided trigger payload.
  """
  def resolve_client_trigger(section_slug, section_id, user_id, params) when is_map(params) do
    trigger = Trigger.parse(params, section_id, user_id)

    case trigger.trigger_type do
      type when type in [:adaptive_page, :adaptive_component] ->
        resolve_adaptive_client_trigger(section_slug, section_id, trigger)

      _ ->
        {:ok, trigger}
    end
  rescue
    ArgumentError -> {:error, :invalid_trigger}
  end

  @doc """
  Invoke a trigger point for a given section id and user id.  This will broadcast
  the trigger to the PubSub system - which will be picked up by the AI agent window process
  and displayed to the user.
  """
  def invoke(section_id, current_user_id, trigger) do
    case maybe_admit_adaptive_trigger(trigger) do
      :ok ->
        topic = "trigger:#{current_user_id}:#{section_id}:#{trigger.resource_id}"

        Logger.info("Invoking trigger for topic: #{topic}")

        PubSub.broadcast(
          Oli.PubSub,
          topic,
          {:trigger, trigger}
        )

      :duplicate ->
        Logger.debug(
          "Suppressing duplicate adaptive trigger for section=#{section_id} user=#{current_user_id} resource=#{trigger.resource_id}"
        )

        :ok

      {:error, reason} = error ->
        Logger.error(
          "Unable to admit adaptive trigger for section=#{section_id} user=#{current_user_id} resource=#{trigger.resource_id}, reason=#{inspect(reason)}"
        )

        error
    end
  end

  @doc """
  Given a section slug, user id, and trigger data, possibly invoke the trigger
  if the user has access to the section.
  """
  def possibly_invoke_trigger(section_slug, user_id, trigger) do
    case verify_access(section_slug, user_id) do
      {:ok, section} ->
        invoke(section.id, user_id, trigger)

      e ->
        e
    end
  end

  @doc """
  Assemble the full trigger prompt for a given trigger.
  """
  def assemble_trigger_prompt(trigger) do
    trigger = augment_data_context(trigger)
    reason = description(trigger.trigger_type, trigger.data)

    """
    AI Activation points are a feature of this platform that allow a course author to instrument
    various points of student interaction in the course to 'activate' your (the AI agent)
    intervention. This is one such AI activation point invocation. The author has configured this activation
    point in response to a student action or event. Do not mention 'activation points' ever.

    Some questions are comprised of multiple parts. You MUST limit your response to only the specified part of the question.

    In this activation point, the student has just #{reason}

    Engage by greeting the student.

    VERY IMPORTANT: The author has also requested the AI agent to
    follow these specific instructions while engaging with the student:

    #{trigger.prompt}
    """
  end

  # Given certain classes of triggers, augment the data context with additional
  # information that will be needed for the AI agent to render the trigger prompt.
  defp augment_data_context(trigger) do
    case trigger do
      # No additional data needed for these trigger types
      %{trigger_type: t}
      when t in [:page, :adaptive_page, :adaptive_component, :content_group, :content_block] ->
        trigger

      # For these trigger types, we need to fetch the question model and encode it
      %{data: %{"activity_attempt_guid" => guid}} ->
        activity_attempt = Oli.Delivery.Attempts.Core.get_activity_attempt_by(attempt_guid: guid)

        student_response =
          Oli.Delivery.Attempts.Core.get_latest_part_attempts(guid)
          |> Enum.map(fn pa ->
            %{
              part_id: pa.part_id,
              student_response: pa.response
            }
          end)
          |> Jason.encode!()

        model = Oli.Delivery.Attempts.Core.select_model(activity_attempt)
        encoded = Jason.encode!(model)

        data =
          Map.put(trigger.data, "question", encoded)
          |> Map.put("student_response", student_response)

        %{trigger | data: data}
    end
  end

  defp resolve_adaptive_client_trigger(_section_slug, section_id, trigger) do
    with {:ok, resource_id} <- normalize_adaptive_resource_id(trigger.resource_id),
         parts_layout when is_list(parts_layout) <-
           get_adaptive_parts_layout(section_id, resource_id),
         {:ok, part} <- find_adaptive_trigger_part(parts_layout, trigger.data),
         {:ok, prompt} <- resolve_adaptive_prompt(trigger.trigger_type, part),
         {:ok, prompt} <- validate_adaptive_prompt(prompt) do
      {:ok,
       %{
         trigger
         | resource_id: resource_id,
           prompt: prompt,
           data: %{
             "component_id" => normalize_component_id(part_id(part), "unknown"),
             "component_type" => normalize_component_type(part_type(part), "component")
           }
       }}
    else
      nil -> {:error, :invalid_trigger}
      {:error, _reason} = error -> error
    end
  end

  defp normalize_adaptive_resource_id(resource_id) when is_integer(resource_id),
    do: {:ok, resource_id}

  defp normalize_adaptive_resource_id(resource_id) when is_binary(resource_id) do
    case Integer.parse(resource_id) do
      {value, ""} -> {:ok, value}
      _ -> {:error, :invalid_trigger}
    end
  end

  defp normalize_adaptive_resource_id(_), do: {:error, :invalid_trigger}

  defp get_adaptive_parts_layout(section_id, resource_id) do
    case SectionResourceDepot.get_section_resource(section_id, resource_id) do
      %{revision_id: revision_id} ->
        revision_id
        |> get_parts_layout_by_revision_id()
        |> normalize_parts_layout()

      _ ->
        Repo.one(
          from(spp in SectionsProjectsPublications,
            where: spp.section_id == ^section_id,
            join: pr in PublishedResource,
            on: pr.publication_id == spp.publication_id,
            where: pr.resource_id == ^resource_id,
            join: rev in Revision,
            on: rev.id == pr.revision_id,
            select: fragment("?->'partsLayout'", rev.content),
            limit: 1
          )
        )
        |> normalize_parts_layout()
    end
  end

  defp get_parts_layout_by_revision_id(revision_id) do
    Repo.one(
      from(r in Revision,
        where: r.id == ^revision_id,
        select: fragment("?->'partsLayout'", r.content)
      )
    )
  end

  defp normalize_parts_layout(parts_layout) when is_list(parts_layout), do: parts_layout
  defp normalize_parts_layout(_), do: nil

  defp find_adaptive_trigger_part(parts_layout, data)
       when is_list(parts_layout) and is_map(data) do
    component_id =
      data
      |> Map.get("component_id")
      |> normalize_component_id(nil)

    case component_id do
      nil ->
        {:error, :invalid_trigger}

      _ ->
        case Enum.find(parts_layout, fn part -> part_id(part) == component_id end) do
          nil -> {:error, :invalid_trigger}
          part -> {:ok, part}
        end
    end
  end

  defp find_adaptive_trigger_part(_, _), do: {:error, :invalid_trigger}

  defp resolve_adaptive_prompt(:adaptive_page, part) do
    case {part_type(part), map_value(part_custom(part), "launchMode")} do
      {@adaptive_page_component_type, "auto"} ->
        {:ok, map_value(part_custom(part), "prompt")}

      _ ->
        {:error, :invalid_trigger}
    end
  end

  defp resolve_adaptive_prompt(:adaptive_component, part) do
    case part_type(part) do
      @adaptive_page_component_type ->
        case map_value(part_custom(part), "launchMode") do
          "click" -> {:ok, map_value(part_custom(part), "prompt")}
          _ -> {:error, :invalid_trigger}
        end

      "janus-image" ->
        case map_value(part_custom(part), "enableAiTrigger") do
          true -> {:ok, map_value(part_custom(part), "aiTriggerPrompt")}
          _ -> {:error, :invalid_trigger}
        end

      "janus-navigation-button" ->
        case map_value(part_custom(part), "enableAiTrigger") do
          true -> {:ok, map_value(part_custom(part), "aiTriggerPrompt")}
          _ -> {:error, :invalid_trigger}
        end

      _ ->
        {:error, :invalid_trigger}
    end
  end

  defp validate_adaptive_prompt(prompt) when is_binary(prompt) do
    trimmed = String.trim(prompt)

    cond do
      trimmed == "" ->
        {:error, :invalid_trigger}

      String.length(trimmed) > @adaptive_prompt_max_length ->
        {:error, :invalid_trigger}

      true ->
        {:ok, trimmed}
    end
  end

  defp validate_adaptive_prompt(_), do: {:error, :invalid_trigger}

  defp maybe_admit_adaptive_trigger(%Trigger{trigger_type: type} = trigger)
       when type in [:adaptive_page, :adaptive_component] do
    trigger
    |> adaptive_trigger_cache_key()
    |> AdaptiveTriggerInvocationCache.register_once(@adaptive_trigger_cooldown_ms)
    |> case do
      :accepted -> :ok
      :duplicate -> :duplicate
      {:error, _reason} = error -> error
    end
  end

  defp maybe_admit_adaptive_trigger(_trigger), do: :ok

  defp adaptive_trigger_cache_key(%Trigger{} = trigger) do
    {
      trigger.section_id,
      trigger.user_id,
      trigger.resource_id,
      trigger.trigger_type,
      sanitize_component_id(trigger.data),
      sanitize_component_type(trigger.data)
    }
  end

  @adaptive_map_atom_keys %{
    "aiTriggerPrompt" => :aiTriggerPrompt,
    "custom" => :custom,
    "enableAiTrigger" => :enableAiTrigger,
    "id" => :id,
    "launchMode" => :launchMode,
    "partsLayout" => :partsLayout,
    "prompt" => :prompt,
    "type" => :type
  }

  defp map_value(map, key) when is_map(map) and is_binary(key) do
    case Map.get(map, key) do
      nil ->
        case Map.get(@adaptive_map_atom_keys, key) do
          nil -> nil
          atom_key -> Map.get(map, atom_key)
        end

      value ->
        value
    end
  end

  defp map_value(_, _), do: nil

  defp part_id(part), do: map_value(part, "id")
  defp part_type(part), do: map_value(part, "type")
  defp part_custom(part), do: map_value(part, "custom") || %{}

  defp normalize_component_type(value, fallback) when is_binary(value) do
    case MapSet.member?(@adaptive_component_types, value) do
      true -> value
      false -> fallback
    end
  end

  defp normalize_component_type(_, fallback), do: fallback

  @doc """
  Check for a hint trigger based on the activity attempt, part attempt, model, and hint.

  If a matching trigger is found, return the trigger, otherwise return nil.
  """
  def check_for_hint_trigger(activity_attempt, part_attempt, model, hint, set_resource_id \\ true) do
    part = Enum.filter(model.parts, fn p -> p.id == part_attempt.part_id end) |> hd()

    hint_ordinal =
      case Enum.find_index(part.hints, fn h -> h.id == hint.id end) do
        nil -> 0
        index -> index + 1
      end

    case Enum.filter(part.triggers, fn t ->
           t.trigger_type == :hint and t.ref_id == hint_ordinal
         end) do
      [trigger | _other] ->
        # we have to look up the page id for this activity attempt
        page_id =
          case set_resource_id do
            true ->
              Repo.one(
                from(ra in ResourceAttempt,
                  join: r in ResourceAccess,
                  on: ra.resource_access_id == r.id,
                  where: ra.id == ^activity_attempt.resource_attempt_id,
                  select: r.resource_id
                )
              )

            false ->
              nil
          end

        %Trigger{
          trigger_type: :hint,
          data: %{
            "ref_id" => hint_ordinal,
            "activity_attempt_guid" => activity_attempt.attempt_guid,
            "activity_id" => activity_attempt.resource_id
          },
          resource_id: page_id,
          prompt: trigger.prompt
        }

      _ ->
        nil
    end
  end

  @doc """
  Check for an explanation trigger based on the part, explanation, and explanation context.

  If a matching trigger is found, return the trigger, otherwise return nil.
  """
  def check_for_explanation_trigger(part, explanation, explanation_context) do
    case Enum.filter(part.triggers, fn t -> t.trigger_type == :explanation end) do
      [] ->
        nil

      [trigger | _other] ->
        {:ok, t} = Oli.Activities.Model.Trigger.parse(trigger)
        payload = Trigger.from_activity_model(t)

        data = %{
          "activity_attempt_guid" => explanation_context.activity_attempt.attempt_guid,
          "ref_id" => explanation.id
        }

        %{
          payload
          | section_id: nil,
            user_id: nil,
            resource_id: explanation_context.resource_revision.resource_id,
            data: data
        }
    end
  end

  @doc """
  For a specific evaluation response, check for the presence of a matching evaluation trigger.

  If a matching trigger is found, return the trigger, otherwise return nil.

  Targeted feedback triggers are given priority over correct/incorrect triggers.
  """
  def check_for_response_trigger(relevant_triggers_by_type, response, part_id, out_of, context) do
    case find_matching_trigger(relevant_triggers_by_type, response, out_of) do
      nil ->
        nil

      trigger ->
        # Now convert the activity model represenattion of the trigger to the
        # the data transfer object representation of the trigger
        {:ok, t} = Oli.Activities.Model.Trigger.parse(trigger)
        payload = Trigger.from_activity_model(t)

        data = %{
          "activity_attempt_guid" => context.activity_attempt_guid,
          "ref_id" => trigger.ref_id,
          "response" => response,
          "part_id" => part_id
        }

        %{payload | section_id: nil, user_id: nil, resource_id: context.page_id, data: data}
    end
  end

  defp find_matching_trigger(relevant_triggers_by_type, response, out_of) do
    # Does this response match a targeted feedback trigger?
    targeted_feedback_trigger =
      Map.get(relevant_triggers_by_type, :targeted_feedback, [])
      |> Enum.find(fn trigger ->
        trigger.ref_id == response.id
      end)

    correct_trigger = Map.get(relevant_triggers_by_type, :correct_answer, [nil]) |> hd()
    incorrect_trigger = Map.get(relevant_triggers_by_type, :incorrect_answer, [nil]) |> hd()

    is_correct? = response.score == out_of

    # Look first for a targeted feedback trigger matching the response
    if targeted_feedback_trigger != nil do
      targeted_feedback_trigger
    else
      # If no targeted feedback trigger, look for a correct/incorrect triggers
      if is_correct? do
        correct_trigger
      else
        incorrect_trigger
      end
    end
  end

  def relevant_triggers_by_type(%Part{} = part) do
    Enum.filter(part.triggers, fn trigger ->
      trigger.trigger_type in evaluation_triggers()
    end)
    |> Enum.group_by(& &1.trigger_type)
  end
end
