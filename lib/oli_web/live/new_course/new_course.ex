defmodule OliWeb.Delivery.NewCourse do
  use OliWeb, :live_view

  alias OliWeb.Common.Stepper
  alias OliWeb.Common.Stepper.Step

  alias Phoenix.LiveView.JS

  @form_id "open_and_free_form"
  def mount(_params, session, socket) do
    steps = [
      %Step{
        title: "Select your base course project or course product",
        description:
          "Select a course project or product on which to base your course curriculum.",
        render_fn: fn assigns -> render_step(:select_source, assigns) end,
        on_next_step: JS.push("change_step", value: %{current_step: 1})
      },
      %Step{
        title: "Name your course",
        description: "Give your course section a name, a number, and tell us how you meet.",
        render_fn: fn assigns -> render_step(:name_course, assigns) end,
        on_previous_step:
          JS.push("change_step", value: %{form_id: "name-course-form", current_step: 0}),
        on_next_step:
          JS.push("change_step", value: %{form_id: "name-course-form", current_step: 2})
      },
      %Step{
        title: "Course details",
        description:
          "If you meet as a group, let us know what days of the week your class meets. Everyone needs to tell us your course’s start and end dates.",
        render_fn: fn assigns -> render_step(:course_details, assigns) end,
        on_previous_step:
          JS.push("change_step", value: %{form_id: "course-details-form", current_step: 1}),
        on_next_step:
          JS.push("change_step", value: %{form_id: "course-details-form", current_step: 3})
      }
    ]

    {:ok,
     assign(socket,
       form_id: @form_id,
       steps: steps,
       current_step: 0,
     )}
  end

  def render(assigns) do
    ~H"""
      <div id={@form_id} phx-hook="SubmitForm">
        <.live_component
          id="course_creation_stepper"
          module={Stepper}
          steps={@steps || []}
          current_step={@current_step}
          data={get_step_data(assigns)} />
      </div>
    """
  end

  slot :inner_block, required: true

  defp header(assigns) do
    ~H"""
      <h5 class="px-9 py-4 border-gray-200 dark:border-gray-600 border-b text-sm font-semibold">
        New course set up
      </h5>
      <div class="overflow-y-auto scrollbar-hide relative h-full">
        <%= render_slot(@inner_block) %>
      </div>
    """
  end

  def render_step(:select_source, assigns) do
    ~H"""
      <.header>
        <div class="flex flex-col items-center gap-3 pl-9 pr-16 py-4">
          <h2>Course details</h2>
          <%= @step_one_prop %>
        </div>
      </.header>
    """
  end

  def render_step(:name_course, assigns) do
    ~H"""
      <.header>
        <div class="flex flex-col items-center gap-3 pl-9 pr-16 py-4">
          <img src="/images/icons/course-creation-wizard-step-1.svg" />
          <h2>Name your course</h2>
          <%= @step_two_prop %>
          <.form let={f} for={:section} id="name-course-form">
            <%= text_input f, :title, class: "torus-input" %>
          </.form>
        </div>
      </.header>
    """
  end

  def render_step(:course_details, assigns) do
    ~H"""
    <.header>
      <div class="flex flex-col items-center gap-3 pl-9 pr-16 py-4">
        <img src="/images/icons/course-creation-wizard-step-2.svg" />
        <h2>Course details</h2>
        <%= @step_three_prop %>
        <.form let={f} for={:section} id="course-details-form">
          <%= text_input f, :description, class: "torus-input" %>
        </.form>
      </div>
    </.header>
    """
  end

  def create_section(socket) do
    IO.inspect("Section created")
  end

  defp get_step_data(assigns) do
    case assigns.current_step do
      0 ->
        %{
          step_one_prop: "Prop example 1"
        }

      1 ->
        %{
          step_two_prop: "Prop example 1"
        }

      _ ->
        %{
          step_three_prop: "Prop example 1"
        }
    end
  end

  def handle_event(
        "change_step",
        %{"form_id" => _form_id, "current_step" => _current_step} = params,
        socket
      ) do
    {:noreply, push_event(socket, "js_form_data_request", Map.put(params, :target_id, @form_id))}
  end

  def handle_event(
        "change_step",
        %{"current_step" => current_step},
        socket
      ) do
    {:noreply, assign(socket, current_step: current_step)}
  end

  # This is the response returned from the SubmitForm hook
  def handle_event(
        "js_form_data_response",
        %{"section" => _section, "current_step" => current_step},
        socket
      ) do
    socket = assign(socket, current_step: current_step)

    if current_step > 2 do
      create_section(socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event(
        "js_form_data_response",
        %{"current_step" => current_step},
        socket
      ) do
    {:noreply, assign(socket, current_step: current_step)}
  end
end
