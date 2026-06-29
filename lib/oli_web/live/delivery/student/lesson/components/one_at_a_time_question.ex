defmodule OliWeb.Delivery.Student.Lesson.Components.OneAtATimeQuestion do
  use OliWeb, :live_component

  import OliWeb.Delivery.Student.Utils,
    only: [references: 1]

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias OliWeb.Components.Common
  alias OliWeb.Components.Modal
  alias OliWeb.Icons

  attr :questions, :list
  attr :attempt_number, :integer
  attr :max_attempt_number, :integer
  attr :datashop_session_id, :string
  attr :ctx, :map
  attr :bib_app_params, :map
  attr :section_slug, :string
  attr :effective_settings, :map

  def render(assigns) do
    ~H"""
    <div id={@id} class="w-full">
      <% selected_question = Enum.find(@questions, & &1.selected) %>
      <% total_questions = Enum.count(@questions) %>
      <% selected_question_points =
        Map.get(selected_question, :out_of, Map.get(selected_question, "outOf")) %>
      <% submitted_questions = Enum.count(@questions, & &1.submitted) %>
      <% unattempted_questions = total_questions - submitted_questions %>
      <Modal.modal id="finish_quiz_confirmation_modal" class="w-auto min-w-[50%]" body_class="px-6">
        <:title>
          Finish Attempt {@attempt_number} of {@max_attempt_number}?
        </:title>

        <div class="text-[#373a44] dark:text-white text-sm font-normal leading-snug">
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
              class="w-[187.52px] h-[30px] px-5 py-2.5 bg-[#0062f2] rounded-md shadow justify-center items-center gap-2.5 inline-flex"
            >
              <div class="justify-end items-center gap-2 flex">
                <div
                  id="submit_answers"
                  class="opacity-90 text-right text-white text-sm font-semibold leading-[14px] whitespace-nowrap"
                >
                  Yes, Finish The Attempt
                </div>
              </div>
            </button>
          </div>
        </:custom_footer>
      </Modal.modal>
      <div class="flex w-full flex-col items-center">
        <div role="questions header" class="w-full max-w-[1170px] lg:pl-[189px]">
          <div class="flex w-full justify-between items-center mb-1">
            <div class="text-[#757682] text-xs font-normal leading-[18px] dark:text-white/80">
              Question {selected_question.number} / {total_questions} • {parse_points(
                selected_question_points
              )}
            </div>
            <%= if @effective_settings.batch_scoring do %>
              <button
                phx-click={Modal.show_modal("finish_quiz_confirmation_modal")}
                class="flex items-center gap-2"
              >
                <div class="opacity-90 text-right text-[#0080ff] text-base font-bold leading-normal">
                  Finish Attempt
                </div>
                <Icons.finish_quiz_flag />
              </button>
            <% else %>
              <div />
            <% end %>
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
        <div
          role="questions main content"
          class="mx-auto grid w-full max-w-[1170px] grid-cols-1 gap-4 lg:grid-cols-[157px_minmax(0,981px)] lg:gap-8"
        >
          <.questions_menu
            questions={@questions}
            myself={@myself}
            batch_scoring={@effective_settings.batch_scoring}
          />
          <div
            role="questions content"
            class="content min-h-[484px] w-full min-w-0 max-w-[981px]"
          >
            <div
              id="react_to_liveview"
              phx-hook="ReactToLiveView"
              class="flex w-full min-w-0"
            >
              <div
                id="eventIntercept_one_at_a_time_question"
                class="w-full min-w-0"
                phx-update="ignore"
              >
                <div
                  :for={question <- @questions}
                  id={"question_#{question.number}"}
                  role="one at a time question"
                  class={[
                    "w-full min-w-0 overflow-visible px-3 py-5 sm:px-6 lg:px-10 lg:py-8",
                    if(!question.selected, do: "hidden")
                  ]}
                  phx-hook="DisableSubmitted"
                  data-submitted={"#{question.submitted and @effective_settings.batch_scoring}"}
                >
                  {raw(question.raw_content)}
                </div>
              </div>
            </div>
            <div
              :if={@effective_settings.batch_scoring}
              class="flex min-h-[84px] w-full min-w-0 items-center justify-center"
            >
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
              <div
                :if={selected_question.submitted}
                class="activity w-full min-w-0 p-2 sm:px-6 lg:px-10"
              >
                <div role="question points feedback" class="flex justify-end mb-2.5">
                  <span class="text-[#8e8e8e] text-xs font-normal leading-[18px] dark:text-white/80">
                    Points:
                  </span>
                  <span class="ml-1 text-[#5e5e5e] text-xs font-semibold leading-[18px] dark:text-white">
                    {question_points(selected_question)} / {total_question_points(selected_question)}
                  </span>
                </div>
                <div role="question feedback" class="activity-content">
                  {OliWeb.Common.React.component(
                    @ctx,
                    "Components.Evaluation",
                    %{
                      attemptState: selected_question.state,
                      context: selected_question.context
                    },
                    id: "activity_evaluation_for_question_#{selected_question.number}",
                    container: [class: "flex flex-col w-full"]
                  )}
                </div>
              </div>
            </div>
            <.references ctx={@ctx} bib_app_params={@bib_app_params} />
          </div>
        </div>
        <div
          role="questions footer"
          class="fixed inset-x-0 bottom-0 z-40 flex w-full gap-2 bg-Surface-surface-background p-3 shadow-[0px_-2px_10px_rgba(0,50,99,0.1)] sm:gap-4 sm:p-4 lg:static lg:z-auto lg:mb-32 lg:w-full lg:max-w-[1170px] lg:gap-0 lg:bg-transparent lg:p-0 lg:pl-[189px] lg:py-8 lg:shadow-none lg:justify-between"
        >
          <button
            phx-click={JS.dispatch("click", to: "#question_#{selected_question.number - 1}_button")}
            disabled={selected_question.number == 1}
            id="previous_question_button"
            class="h-11 min-w-0 flex-1 rounded-md border bg-white px-2 py-2 shadow justify-center items-center gap-1.5 inline-flex sm:px-5 sm:py-2.5 sm:gap-2.5 lg:h-[30px] lg:w-[117.45px] lg:flex-none"
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
            class="h-11 min-w-0 flex-1 rounded-md border bg-white px-2 py-2 shadow justify-center items-center gap-1.5 inline-flex sm:px-5 sm:py-2.5 sm:gap-2.5 lg:h-[30px] lg:w-[93.51px] lg:flex-none"
          >
            <div class="justify-end items-center gap-2 flex">
              <span class="opacity-90 text-right text-[#0062f2] text-sm font-semibold leading-[14px]">
                Next
              </span>
              <Icons.next_question_arrow />
            </div>
          </button>

          <button
            :if={selected_question.number == total_questions and @effective_settings.batch_scoring}
            phx-click={Modal.show_modal("finish_quiz_confirmation_modal")}
            class="h-11 min-w-0 flex-1 rounded-md bg-[#0062f2] px-2 py-2 shadow justify-center items-center gap-1.5 inline-flex opacity-90 text-right text-white text-sm font-semibold leading-[14px] whitespace-nowrap sm:px-5 sm:py-2.5 sm:gap-2.5 lg:h-[30px] lg:w-[130px] lg:flex-none"
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
    <div
      id="questions_menu"
      class="my-2 flex w-full flex-wrap gap-x-1 gap-y-2 px-3 py-2 lg:h-auto lg:w-[157px] lg:flex-col lg:flex-nowrap lg:gap-0 lg:px-0 lg:py-0"
    >
      <button
        :for={question <- @questions}
        id={"question_#{question.number}_button"}
        phx-click={select_question(question.number)}
        phx-target={if @batch_scoring, do: @myself, else: nil}
        disabled={question.selected}
        phx-value-id={question.number}
        class={[
          "flex h-6 w-6 items-center justify-center lg:h-[33px] lg:w-full lg:justify-start lg:gap-[18px] lg:pl-[16.5px]",
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
          "hidden whitespace-nowrap text-[#353740] text-base font-normal leading-normal dark:text-white lg:inline",
          if(question.selected, do: "!text-[#0f6bf5] !font-bold")
        ]}>
          Question {question.number}
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

  def handle_event("activity_saved", params, socket) do
    {:noreply, update_activity(socket, params)}
  end

  def handle_event("select_question", %{"question_number" => question_number}, socket) do
    questions =
      socket.assigns.questions
      |> Enum.map(fn question ->
        Map.put(question, :selected, question.number == question_number)
      end)

    {:noreply, assign(socket, questions: questions)}
  end

  def handle_event(
        "submit_selected_question",
        %{"attempt_guid" => attempt_guid, "question_id" => question_id},
        socket
      ) do
    ## evaluate the activity attempt

    Core.get_activity_attempt_by(attempt_guid: attempt_guid)
    |> Oli.Repo.preload([:resource_attempt, :part_attempts, :revision])
    |> Evaluate.update_part_attempts_for_activity(
      socket.assigns.datashop_session_id,
      socket.assigns.effective_settings
    )

    ## and update it's state in the assigns (to render the feedback in the UI)

    questions =
      Enum.map(socket.assigns.questions, fn
        %{selected: true} = selected_question ->
          Map.merge(selected_question, %{
            state: get_updated_state(attempt_guid, socket.assigns.effective_settings),
            submitted: true
          })

        not_selected_question ->
          not_selected_question
      end)

    # Send a message to self to push the event after render
    send(self(), {:disable_question_inputs, question_id})

    {:noreply, assign(socket, questions: questions)}
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

  def get_updated_state(attempt_guid, effective_settings) do
    {:ok, [attempt]} = Oli.Delivery.Attempts.Core.get_activity_attempts([attempt_guid])
    model = Oli.Delivery.Attempts.Core.select_model(attempt)

    {:ok, parsed_model} = Oli.Activities.Model.parse(model)

    Oli.Activities.State.ActivityState.from_attempt(
      attempt,
      Oli.Delivery.Attempts.Core.get_latest_part_attempts(attempt.attempt_guid),
      parsed_model,
      nil,
      nil,
      effective_settings
    )
    # string keys are expected...
    |> Jason.encode!()
    |> Jason.decode!()
  end

  defp get_progress([] = _questions), do: 0.5

  defp get_progress(questions) do
    total_questions = Enum.count(questions)
    submitted_questions = Enum.count(questions, fn question -> question.submitted end)

    if submitted_questions == 0, do: 0.5, else: submitted_questions / total_questions * 100
  end

  defp parse_points(points) when is_nil(points), do: "0 points"
  defp parse_points(1), do: "1 point"
  defp parse_points(1.0), do: "1 point"
  defp parse_points(points) when is_integer(points), do: "#{points} points"
  defp parse_points(points), do: "#{Float.round(points, 2)} points"

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
end
