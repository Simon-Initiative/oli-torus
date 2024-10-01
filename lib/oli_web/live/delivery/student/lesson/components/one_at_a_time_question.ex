defmodule OliWeb.Delivery.Student.Lesson.Components.OneAtATimeQuestion do
  use OliWeb, :live_component

  import OliWeb.Delivery.Student.Utils,
    only: [references: 1]

  require Logger

  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.PageLifecycle.FinalizationSummary
  alias Oli.Delivery.Sections

  alias OliWeb.Components.Common
  alias OliWeb.Components.Modal
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Icons

  attr :questions, :list
  attr :attempt_number, :integer
  attr :max_attempt_number, :integer
  attr :datashop_session_id, :string
  attr :ctx, :map
  attr :bib_app_params, :map
  attr :request_path, :string
  attr :revision_slug, :string
  attr :attempt_guid, :string
  attr :section_slug, :string

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <% selected_question = Enum.find(@questions, & &1.selected) %>
      <% total_questions = Enum.count(@questions) %>
      <% selected_question_points =
        Enum.reduce(selected_question.part_points, 0, fn {_id, points}, acum ->
          points + acum
        end) %>
      <% selected_question_parts_count = map_size(selected_question.part_points) %>
      <% submitted_questions = Enum.count(@questions, & &1.submitted) %>
      <% unattempted_questions = total_questions - submitted_questions %>
      <Modal.modal id="finish_quiz_confirmation_modal" class="w-auto min-w-[50%]" body_class="px-6">
        <:title>
          Finish Attempt <%= @attempt_number %> of <%= @max_attempt_number %>?
        </:title>

        <div class="text-[#373a44] text-sm font-normal leading-snug">
          You are about to submit your attempt<span :if={unattempted_questions > 0}> with <strong><%= unattempted_questions %></strong> unattempted question<%= if unattempted_questions == 1, do: "", else: "s" %></span>.
          <br :if={unattempted_questions > 0} /> Are you sure you want to proceed?
        </div>

        <:custom_footer>
          <div class="flex gap-3.5 w-full h-16 p-4 mt-6 border-t border-[#e7e7e7]">
            <button
              phx-click={Modal.hide_modal("finish_quiz_confirmation_modal")}
              class="ml-auto w-[84px] h-[30px] px-5 py-2.5 bg-white rounded-md shadow border border-[#0f6bf5] justify-center items-center gap-2.5 inline-flex"
            >
              <div class="pr-2 justify-end items-center gap-2 flex">
                <div class="opacity-90 text-right text-[#0062f2] text-sm font-semibold leading-[14px]">
                  Cancel
                </div>
              </div>
            </button>
            <button
              phx-click="finalize_attempt"
              phx-target={@myself}
              class="w-[187.52px] h-[30px] px-5 py-2.5 bg-[#0062f2] rounded-md shadow justify-center items-center gap-2.5 inline-flex"
            >
              <div class="justify-end items-center gap-2 flex">
                <div class="opacity-90 text-right text-white text-sm font-semibold leading-[14px] whitespace-nowrap">
                  Yes, Finish The Attempt
                </div>
              </div>
            </button>
          </div>
        </:custom_footer>
      </Modal.modal>
      <div class="w-screen flex flex-col items-center">
        <div role="questions header" class="w-[1170px] pl-[189px]">
          <div class="flex w-full justify-between items-center mb-1">
            <div class="text-[#757682] text-xs font-normal leading-[18px]">
              Question <%= selected_question.number %> / <%= total_questions %> • <%= parse_points(
                selected_question_points
              ) %>
            </div>
            <button
              phx-click={Modal.show_modal("finish_quiz_confirmation_modal")}
              disabled={selected_question.number != total_questions}
              class="flex items-center gap-2"
            >
              <div class="opacity-90 text-right text-[#0080ff] text-base font-bold leading-normal">
                Finish Attempt
              </div>
              <Icons.finish_quiz_flag />
            </button>
          </div>
          <div class="mb-3">
            <Common.progress_bar
              percent={get_progress(@questions)}
              role="progress bar"
              height="h-1"
              rounded="rounded-none"
              on_going_colour="bg-[#0062f2]"
              completed_colour="bg-[#0062f2]"
              not_completed_colour="bg-[#1c1c1c]/10"
              show_percent={false}
            />
          </div>
        </div>
        <div role="questions main content" class="mx-auto flex justify-center gap-8 w-full">
          <.questions_menu questions={@questions} myself={@myself} />
          <div
            role="questions content"
            class="content min-h-[484px] w-[981px] rounded-md border border-[#c8c8c8]"
          >
            <div
              id="react_to_liveview"
              phx-hook="ReactToLiveView"
              class="flex h-[400px] border-b border-[#c8c8c8]"
            >
              <div id="eventIntercept" phx-update="ignore">
                <div
                  :for={question <- @questions}
                  id={"question_#{question.number}"}
                  role="one at a time question"
                  class={[
                    "overflow-scroll p-10 h-[400px] oveflow-hidden",
                    if(map_size(question.part_points) == 1, do: "w-[981px]", else: "w-[808px]"),
                    if(!question.selected, do: "hidden")
                  ]}
                  phx-hook="DisableSubmitted"
                  data-submitted={"#{question.submitted}"}
                >
                  <%= raw(question.raw_content) %>
                </div>
              </div>
              <div
                :if={selected_question_parts_count > 1}
                role="parts score summary"
                class="w-[173px] px-3 py-6 gap-2 text-sm font-normal leading-none whitespace-nowrap border-l border-[#c8c8c8]"
              >
                <div
                  :for={{{id, points}, index} <- Enum.with_index(selected_question.part_points, 1)}
                  class="flex items-center h-6"
                >
                  <span class="w-4">
                    <.part_result_icon part={
                      Enum.find(selected_question.state["parts"], &(&1["partId"] == id))
                    } />
                  </span>
                  <span class="text-[#757682] ml-4">
                    Part <%= index %>:
                  </span>
                  <span class="text-[#353740] ml-1">
                    <%= parse_points(points) %>
                  </span>
                </div>
              </div>
            </div>
            <div class="flex justify-center w-full min-h-[84px] items-center">
              <button
                :if={!selected_question.submitted}
                phx-click="submit_selected_question"
                phx-target={@myself}
                phx-value-attempt_guid={selected_question.state["attemptGuid"]}
                phx-value-question_id={"question_#{selected_question.number}"}
                disabled={!selected_question.answered}
                class={[
                  "h-[30px] px-5 py-2.5 rounded-md shadow justify-center items-center gap-2.5 inline-flex opacity-90 text-right text-base text-white leading-normal whitespace-nowrap",
                  if(selected_question.answered,
                    do: "bg-[#0062f2] font-semibold",
                    else: "bg-[#9d9d9d] font-semibold "
                  )
                ]}
              >
                Submit Response
              </button>
              <div :if={selected_question.submitted} class="activity w-full p-2 px-10">
                <div role="question points feedback" class="flex justify-end mb-2.5">
                  <span class="text-[#8e8e8e] text-xs font-normal leading-[18px]">
                    Points:
                  </span>
                  <span class="ml-1 text-[#5e5e5e] text-xs font-semibold leading-[18px]">
                    <%= question_points(selected_question) %> / <%= total_question_points(
                      selected_question
                    ) %>
                  </span>
                </div>
                <div role="question feedback" class="activity-content">
                  <%= OliWeb.Common.React.component(
                    @ctx,
                    "Components.Evaluation",
                    %{
                      attemptState: selected_question.state,
                      context: selected_question.context,
                      showExplanation: false
                    },
                    id: "activity_evaluation_for_question_#{selected_question.number}",
                    container: [class: "flex flex-col w-full"]
                  ) %>
                </div>
              </div>
            </div>
            <.references ctx={@ctx} bib_app_params={@bib_app_params} />
          </div>
        </div>
        <div role="questions footer" class="w-[1170px] pl-[189px] mb-32 py-8 flex justify-between">
          <button
            phx-click={JS.dispatch("click", to: "#question_#{selected_question.number - 1}_button")}
            disabled={selected_question.number == 1}
            id="previous_question_button"
            class="w-[117.45px] h-[30px] px-5 py-2.5 bg-white rounded-md shadow border justify-center items-center gap-2.5 inline-flex"
          >
            <div class="justify-end items-center gap-2 flex">
              <Icons.previous_question_arrow selected_question_number={selected_question.number} />
              <span class={[
                "opacity-90 text-right text-[#0062f2] text-sm font-semibold leading-[14px]",
                if(selected_question.number == 1, do: "!text-[#9b9b9b]")
              ]}>
                Previous
              </span>
            </div>
          </button>

          <button
            :if={selected_question.number < total_questions}
            id="next_question_button"
            phx-click={JS.dispatch("click", to: "#question_#{selected_question.number + 1}_button")}
            class="w-[93.51px] h-[30px] px-5 py-2.5 bg-white rounded-md shadow border justify-center items-center gap-2.5 inline-flex"
          >
            <div class="justify-end items-center gap-2 flex">
              <span class="opacity-90 text-right text-[#0062f2] text-sm font-semibold leading-[14px]">
                Next
              </span>
              <Icons.next_question_arrow />
            </div>
          </button>

          <button
            :if={selected_question.number == total_questions}
            phx-click={Modal.show_modal("finish_quiz_confirmation_modal")}
            class="w-[130px] h-[30px] px-5 py-2.5 bg-[#0062f2] rounded-md shadow justify-center items-center gap-2.5 inline-flex opacity-90 text-right text-white text-sm font-semibold leading-[14px] whitespace-nowrap"
          >
            Finish Attempt
          </button>
        </div>
      </div>
    </div>
    """
  end

  def questions_menu(assigns) do
    ~H"""
    <div id="questions_menu" class="w-[157px] h-[468px] ml-0 my-2 overflow-y-scroll flex flex-col">
      <button
        :for={question <- @questions}
        id={"question_#{question.number}_button"}
        phx-click={select_question(question.number)}
        phx-target={@myself}
        disabled={question.selected}
        phx-value-id={question.number}
        class={[
          "flex items-center gap-[18px] h-[33px] pl-[16.5px]",
          if(question.selected, do: "!bg-[#0f6bf5]/5")
        ]}
      >
        <div class={[
          "w-2.5 h-2.5 rounded-full",
          if(question.selected, do: "!border-2 !border-[#0062f2]"),
          if(question.submitted, do: "bg-[#0062f2]", else: "bg-[#d9d9d9]")
        ]}>
        </div>
        <span class={[
          "text-[#353740] text-base font-normal leading-normal",
          if(question.selected, do: "!text-[#0f6bf5] !font-bold")
        ]}>
          Question <%= question.number %>
        </span>
      </button>
    </div>
    """
  end

  defp select_question(js \\ %JS{}, question_number) do
    js
    |> JS.push("select_question", value: %{question_number: question_number})
    |> JS.hide(to: "div[role='one at a time question']")
    |> JS.show(to: "#question_#{question_number}")
  end

  def handle_event("select_question", %{"question_number" => question_number}, socket) do
    questions =
      socket.assigns.questions
      |> Enum.map(fn question ->
        Map.put(question, :selected, question.number == question_number)
      end)

    {:noreply, assign(socket, questions: questions)}
  end

  def handle_event("activity_saved", params, socket) do
    {:noreply, update_activity(socket, params)}
  end

  def handle_event(
        "submit_selected_question",
        %{"attempt_guid" => attempt_guid, "question_id" => question_id},
        socket
      ) do
    ## evaluate the activity attempt

    Oli.Repo.get_by(Oli.Delivery.Attempts.Core.ActivityAttempt,
      attempt_guid: attempt_guid
    )
    |> Oli.Repo.preload([:resource_attempt, :part_attempts, :revision])
    |> Oli.Delivery.Attempts.ActivityLifecycle.Evaluate.update_part_attempts_for_activity(
      socket.assigns.datashop_session_id
    )

    ## and update it's state in the assigns (to render the feedback in the UI)

    questions =
      Enum.map(socket.assigns.questions, fn
        %{selected: true} = selected_question ->
          Map.merge(selected_question, %{
            state: get_updated_state(attempt_guid),
            submitted: true
          })

        not_selected_question ->
          not_selected_question
      end)

    # Send a message to self to push the event after render
    send(self(), {:disable_question_inputs, question_id})

    {:noreply, assign(socket, questions: questions)}
  end

  def handle_event(
        "finalize_attempt",
        _params,
        %{
          assigns: %{
            section_slug: section_slug,
            datashop_session_id: datashop_session_id,
            request_path: request_path,
            revision_slug: revision_slug,
            attempt_guid: attempt_guid
          }
        } = socket
      ) do
    case PageLifecycle.finalize(section_slug, attempt_guid, datashop_session_id) do
      {:ok,
       %FinalizationSummary{
         graded: true,
         resource_access: %Oli.Delivery.Attempts.Core.ResourceAccess{id: id}
       }} ->
        # graded resource finalization success
        section = Sections.get_section_by(slug: section_slug)

        if section.grade_passback_enabled,
          do: PageLifecycle.GradeUpdateWorker.create(section.id, id, :inline)

        {:noreply,
         redirect(socket,
           to: Utils.lesson_live_path(section_slug, revision_slug, request_path: request_path)
         )}

      {:ok, %FinalizationSummary{graded: false}} ->
        {:noreply,
         redirect(socket,
           to: Utils.lesson_live_path(section_slug, revision_slug, request_path: request_path)
         )}

      {:error, {reason}}
      when reason in [:already_submitted, :active_attempt_present, :no_more_attempts] ->
        {:noreply, put_flash(socket, :error, "Unable to finalize page")}

      e ->
        error_msg = Kernel.inspect(e)
        Logger.error("Page finalization error encountered: #{error_msg}")
        Oli.Utils.Appsignal.capture_error(error_msg)

        {:noreply, put_flash(socket, :error, "Unable to finalize page")}
    end
  end

  defp update_activity(socket, params) do
    %{
      "activityAttemptGuid" => activity_attempt_guid,
      "partInputs" => [
        %{
          "attemptGuid" => part_attempt_guid
        } = activity_part
      ]
    } = params

    updated_questions =
      Enum.map(socket.assigns.questions, fn
        %{state: %{"attemptGuid" => attempt_guid}} = question
        when attempt_guid == activity_attempt_guid ->
          updated_parts =
            Enum.map(question.state["parts"], fn
              %{"attemptGuid" => attempt_guid} = part
              when attempt_guid == part_attempt_guid ->
                Map.merge(part, activity_part)

              part ->
                part
            end)

          update_in(question, [:state, "parts"], fn _ -> updated_parts end)
          |> update_answered_status()

        question ->
          question
      end)

    assign(socket, questions: updated_questions)
  end

  defp update_answered_status(question) do
    %{
      question
      | answered:
          !Enum.any?(question.state["parts"], fn part -> part["response"] in ["", nil] end)
    }
  end

  defp get_updated_state(attempt_guid) do
    {:ok, [attempt]} = Oli.Delivery.Attempts.Core.get_activity_attempts([attempt_guid])
    model = Oli.Delivery.Attempts.Core.select_model(attempt)

    {:ok, parsed_model} = Oli.Activities.Model.parse(model)

    Oli.Activities.State.ActivityState.from_attempt(
      attempt,
      Oli.Delivery.Attempts.Core.get_latest_part_attempts(attempt.attempt_guid),
      parsed_model,
      nil,
      nil
    )
    # string keys are expected...
    |> Jason.encode!()
    |> Jason.decode!()
  end

  attr :part, :map, required: true

  def part_result_icon(%{part: %{"dateEvaluated" => nil}} = assigns) do
    ~H"""
    """
  end

  def part_result_icon(%{part: %{"score" => score, "outOf" => out_of}} = assigns)
      when score == out_of and score != 0 do
    ~H"""
    <Icons.check />
    """
  end

  def part_result_icon(assigns) do
    ~H"""
    <Icons.close class="stroke-red-500 dark:stroke-white" />
    """
  end

  defp question_points(selected_question) do
    Enum.reduce(selected_question.state["parts"], 0.0, fn part, acum ->
      part["score"] + acum
    end)
  end

  defp total_question_points(selected_question) do
    Enum.reduce(
      selected_question.part_points,
      0.0,
      fn {_id, points}, acum ->
        points + acum
      end
    )
  end

  defp get_progress([] = _questions), do: 0.5

  defp get_progress(questions) do
    total_questions = Enum.count(questions)
    submitted_questions = Enum.count(questions, fn question -> question.submitted end)

    if submitted_questions == 0, do: 0.5, else: submitted_questions / total_questions * 100
  end

  defp parse_points(1), do: "1 point"
  defp parse_points(points), do: "#{points} points"
end
