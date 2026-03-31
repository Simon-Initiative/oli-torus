defmodule OliWeb.Products.ImagePreview do
  use Phoenix.Component

  alias Oli.Branding
  alias OliWeb.Components.Modal
  alias OliWeb.Common.CardListing
  alias OliWeb.Delivery.NewCourse.TableModel
  alias OliWeb.Delivery.StudentOnboarding.Intro
  alias OliWeb.Icons
  alias OliWeb.Workspaces.Student
  alias Phoenix.LiveView.JS

  @contexts [
    %{id: :student_welcome, label: "Student Welcome", width: 1200, height: 628, scale: 0.1523625},
    %{id: :my_course, label: "My Course", width: 1200, height: 628, scale: 0.1523625},
    %{id: :course_picker, label: "Course Picker", width: 1200, height: 628, scale: 0.1523625}
  ]

  attr :section, :map, required: true
  attr :ctx, :map, required: true
  attr :selected_context, :atom, default: :my_course
  attr :modal_open?, :boolean, default: false

  def render(assigns) do
    selected_context = normalize_context(assigns.selected_context)
    preview_section = preview_section(assigns.section)

    assigns =
      assigns
      |> assign(:contexts, @contexts)
      |> assign(:preview_section, preview_section)
      |> assign(:selected_context, selected_context)
      |> assign(:modal_title, modal_title(selected_context))
      |> assign(:has_previous?, has_previous_context?(selected_context))
      |> assign(:has_next?, has_next_context?(selected_context))
      |> assign(:course_picker_model, preview_table_model(preview_section, assigns.ctx))

    ~H"""
    <div id="img-preview-gallery" class="col-span-12 flex flex-col gap-4">
      <div
        id="selected-image-preview"
        class="flex justify-start"
        data-preview-context="cover_image"
      >
        <div class="h-[194px] w-[290px] overflow-hidden">
          <img
            id="current-product-img"
            src={@section.cover_image}
            class="h-full w-full object-cover object-center"
            alt="Selected cover image preview"
          />
        </div>
      </div>

      <div
        id="image-preview-thumbnails"
        class="flex flex-col gap-3 md:flex-row md:items-start md:gap-[15.235px]"
        role="list"
      >
        <%= for context <- @contexts do %>
          <div
            id={"image-preview-thumbnail-#{context_id(context.id)}"}
            class="image-preview-thumbnail group flex cursor-pointer justify-start rounded-sm text-left focus:outline-none"
            data-preview-context={context.id}
            role="button"
            aria-label={context.label}
            tabindex="0"
            phx-click="open_image_preview_modal"
            phx-keyup="open_image_preview_modal"
            phx-keydown="open_image_preview_modal"
            phx-value-context={context.id}
          >
            <div
              class="rounded-sm border border-transparent transition-shadow duration-150 hover:border-Border-border-hover hover:shadow-[0_12px_32px_rgba(15,13,15,0.24)] group-focus-visible:border-Border-border-hover group-focus-visible:shadow-[0_12px_32px_rgba(15,13,15,0.24)]"
              style={"width: #{context.width * context.scale}px; height: #{context.height * context.scale}px;"}
            >
              <div class="h-full w-full overflow-hidden">
                <div
                  class="origin-top-left pointer-events-none select-none"
                  inert
                  aria-hidden="true"
                  style={"width: #{context.width}px; transform: scale(#{context.scale}); transform-origin: top left;"}
                >
                  <.preview_content
                    section={@preview_section}
                    ctx={@ctx}
                    context={context.id}
                    course_picker_model={@course_picker_model}
                  />
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <Modal.modal
        :if={@modal_open?}
        id="image-preview-modal"
        show={true}
        on_cancel={JS.push("close_image_preview_modal")}
        class="max-w-[1100px]"
        body_class="px-6 pb-6 pt-2"
      >
        <:title>{@modal_title}</:title>
        <div class="flex items-center justify-center gap-4 rounded-sm bg-gray-100 px-2 py-4 dark:bg-[#111827]">
          <button
            type="button"
            class={[
              "flex h-12 w-12 shrink-0 items-center justify-center bg-transparent transition",
              if(@has_previous?,
                do: "hover:opacity-85",
                else: "cursor-not-allowed opacity-50"
              )
            ]}
            phx-click="show_previous_image_preview"
            disabled={!@has_previous?}
            aria-label="Show previous preview"
          >
            <Icons.circle_chevron_left_blue class="h-9 w-9" />
          </button>

          <div
            class="origin-top-left overflow-hidden"
            style={"width: #{modal_frame_width(@selected_context)}px; height: #{modal_frame_height(@selected_context)}px;"}
          >
            <div
              class="origin-top-left"
              inert
              aria-hidden="true"
              style={"width: #{context_dimensions(@selected_context).width}px; transform: scale(#{modal_scale(@selected_context)}); transform-origin: top left;"}
            >
              <.preview_content
                section={@preview_section}
                ctx={@ctx}
                context={@selected_context}
                course_picker_model={@course_picker_model}
              />
            </div>
          </div>

          <button
            type="button"
            class={[
              "flex h-12 w-12 shrink-0 items-center justify-center bg-transparent transition",
              if(@has_next?,
                do: "hover:opacity-85",
                else: "cursor-not-allowed opacity-50"
              )
            ]}
            phx-click="show_next_image_preview"
            disabled={!@has_next?}
            aria-label="Show next preview"
          >
            <Icons.circle_chevron_right_blue class="h-9 w-9" />
          </button>
        </div>
        <:custom_footer>
          <div class="flex items-center justify-center px-6 pb-6 pt-2">
            <div class="flex items-center gap-2">
              <%= for context <- @contexts do %>
                <button
                  type="button"
                  class={[
                    "h-2.5 w-2.5 rounded-full",
                    if(context.id == @selected_context,
                      do: "bg-delivery-primary",
                      else: "bg-gray-300 dark:bg-gray-600"
                    )
                  ]}
                  phx-click="select_image_preview_context"
                  phx-value-context={context.id}
                  aria-label={modal_title(context.id)}
                  aria-pressed={to_string(context.id == @selected_context)}
                />
              <% end %>
            </div>
          </div>
        </:custom_footer>
      </Modal.modal>
    </div>
    """
  end

  attr :section, :map, required: true
  attr :ctx, :map, required: true
  attr :context, :atom, required: true
  attr :course_picker_model, :any, default: nil

  def preview_content(%{context: :my_course} = assigns) do
    ~H"""
    <div
      class="h-[628px] w-[1200px] overflow-hidden bg-white text-gray-900 dark:bg-[#0B0C11] dark:text-white"
      data-preview-mode="true"
    >
      <.preview_top_bar user_name={preview_user_name(@ctx)} section={@section} />
      <div class="h-[calc(100%-56px)]">
        <div class="relative flex items-center min-h-[180px] w-full bg-gray-100 dark:bg-[#0B0C11]">
          <div
            class="absolute top-0 left-0 h-full w-full dark:hidden"
            style="background: linear-gradient(90deg, #D9D9D9 0%, rgba(217, 217, 217, 0.00) 100%);"
          />
          <div
            class="absolute top-0 left-0 hidden h-full w-full dark:block"
            style="background: linear-gradient(90deg, rgba(217, 217, 217, 0.250) 0%, rgba(217, 217, 217, 0.00) 100%);"
          />
          <h1 class="text-[64px] leading-[87px] tracking-[0.02px] pl-[100px] z-10">
            Hi, <span class="font-bold">{preview_user_name(@ctx)}</span>
          </h1>
        </div>
        <div class="flex flex-col items-start px-[100px] py-[36px]">
          <div class="mb-6 flex w-full">
            <h2 class="w-full text-[26px] leading-[32px] tracking-[0.02px] font-semibold">
              Courses available
            </h2>
            <div class="ml-auto flex items-center w-full justify-end gap-3">
              <div class="input-group search-input flex gap-2 w-full max-w-[400px]">
                <div class="relative flex flex-1 items-center">
                  <input
                    type="text"
                    class="form-control h-full pr-6 dark:!bg-[#111827] dark:!text-white dark:!border-gray-600"
                    placeholder="Search by course or instructor name"
                  />
                  <button
                    type="button"
                    class="absolute my-auto right-2 h-6 w-6 rounded-full"
                    tabindex="-1"
                  >
                    <i class="fa-solid fa-xmark" />
                  </button>
                </div>
              </div>
            </div>
          </div>
          <div class="flex w-full">
            <div class="flex flex-col w-full gap-3">
              <Student.course_card
                index={0}
                section={@section}
                params={%{sidebar_expanded: true}}
                ctx={@ctx}
                preview_mode={true}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def preview_content(%{context: :course_picker} = assigns) do
    assigns =
      if is_nil(assigns.course_picker_model) do
        assign(assigns, :course_picker_model, preview_table_model(assigns.section, assigns.ctx))
      else
        assigns
      end

    ~H"""
    <div
      class="relative h-[628px] w-[1200px] overflow-hidden text-gray-900 dark:text-white"
      data-preview-mode="true"
    >
      <.preview_top_bar user_name={preview_user_name(@ctx)} section={@section} />
      <div class="relative h-[calc(100%-56px)] w-full">
        <div class="absolute inset-0 flex">
          <div class="h-full w-2/5 bg-blue-700 dark:bg-black" />
          <div class="h-full w-3/5 bg-[#f8fafc] dark:bg-[#111827]" />
        </div>

        <div class="absolute inset-0 flex px-10 py-6">
          <div class="z-20 my-auto w-[34%]">
            <div class="flex flex-col gap-[34px] -mr-[34px]">
              <.preview_step_item
                index={1}
                title="Select your source materials"
                description="Select the source of materials to base your course curriculum on."
                active={true}
              />
              <.preview_step_item
                index={2}
                title="Name your course"
                description="Give your course section a name, a number, and tell us how you meet."
                active={false}
              />
              <.preview_step_item
                index={3}
                title="Course details"
                description="Set meeting days plus the start and end dates for your course."
                active={false}
              />
            </div>
          </div>

          <div class="mb-12 mt-2 flex w-[66%] flex-col overflow-hidden bg-white shadow-xl dark:bg-[#0B0C11] dark:shadow-none">
            <div class="border-b border-gray-200 px-9 py-4 text-sm font-semibold dark:border-gray-700">
              New Course Setup
            </div>
            <div class="flex-1 overflow-hidden">
              <div class="flex h-full flex-col overflow-hidden">
                <div class="-mt-60 flex flex-col items-center gap-3 py-6 pl-16 pr-9">
                  <h2>Select source</h2>
                  <div class="w-full">
                    <div class="mb-3 w-full">
                      <h3 class="pb-2 text-[28px] font-semibold">Select Curriculum</h3>
                      <div>
                        <p class="mb-4 mt-1">
                          Select a curriculum source to create your course section.
                        </p>
                        <div class="filter-opts flex flex-wrap items-center gap-2">
                          <div class="w-full">
                            <div class="input-group search-input flex gap-2">
                              <div class="relative flex flex-1 items-center">
                                <input
                                  type="text"
                                  class="form-control h-full pr-6 dark:!bg-[#111827] dark:!text-white dark:!border-gray-600"
                                  placeholder="Search..."
                                />
                                <button
                                  type="button"
                                  class="absolute right-2 my-auto h-6 w-6 rounded-full"
                                  tabindex="-1"
                                >
                                  <i class="fa-solid fa-xmark" />
                                </button>
                              </div>
                              <button
                                class="btn btn-outline-secondary border-none bg-delivery-primary text-white"
                                type="button"
                              >
                                Search
                              </button>
                            </div>
                          </div>
                          <div class="flex w-full items-center gap-3">
                            <div class="flex min-w-0 flex-1 items-center gap-2">
                              <div class="flex h-10 min-w-0 flex-1 items-center rounded border border-gray-300 bg-white px-3 text-sm text-gray-700 shadow-sm dark:border-gray-600 dark:bg-[#111827] dark:text-white">
                                Title
                              </div>
                              <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded border border-gray-300 bg-white text-gray-700 shadow-sm dark:border-gray-600 dark:bg-[#111827] dark:text-white">
                                <i class="fa fa-sort-amount-down" />
                              </div>
                            </div>
                            <div class="flex shrink-0 items-center overflow-hidden rounded border border-gray-300 shadow-sm dark:border-gray-600">
                              <div class="flex h-10 w-10 items-center justify-center bg-white text-gray-600 dark:bg-[#111827] dark:text-white">
                                <i class="fa fa-list" />
                              </div>
                              <div class="flex h-10 w-10 items-center justify-center bg-delivery-primary-100 text-delivery-primary dark:bg-gray-700 dark:text-white">
                                <i class="fa fa-th" />
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                    <div class="pb-5">
                      <div>Showing all results (1 total)</div>
                      <br />
                      <%= if @course_picker_model do %>
                        <CardListing.render
                          model={@course_picker_model}
                          selected="source_selection"
                          ctx={@ctx}
                          preview_mode={true}
                        />
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div class="flex items-center justify-between bg-gray-100/50 p-3 dark:bg-black/40">
              <button class="torus-button secondary !py-[10px] !px-5 !rounded-[3px] !text-sm flex items-center justify-center dark:!text-white dark:!bg-black dark:hover:!bg-gray-900">
                Cancel
              </button>
              <button
                class="torus-button primary !py-[10px] !px-5 !rounded-[3px] !text-sm flex items-center justify-center"
                disabled
              >
                Next step
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def preview_content(%{context: :student_welcome} = assigns) do
    ~H"""
    <div
      class="relative h-[628px] w-[1200px] overflow-hidden text-gray-900 dark:text-white"
      data-preview-mode="true"
    >
      <.preview_top_bar user_name={preview_user_name(@ctx)} section={@section} />
      <div class="relative h-[calc(100%-56px)] w-full">
        <div class="absolute inset-0 flex">
          <div class="h-full w-2/5 bg-blue-700 dark:bg-black" />
          <div class="h-full w-3/5 bg-[#f8fafc] dark:bg-[#111827]" />
        </div>

        <div class="absolute inset-0 flex px-10 py-6">
          <div class="z-20 my-auto w-[34%]">
            <div class="flex items-center">
              <div class="flex max-w-[280px] flex-col text-white">
                <h4 class="mb-[9px] text-[20px] font-bold leading-5 tracking-[0.02px]">
                  Introduction
                </h4>
                <p class="text-[16px] font-normal leading-[24px] tracking-[0.02px]">
                  Welcome to {@section.title}! Here's what you can expect during this set up process.
                </p>
              </div>
            </div>
          </div>

          <div class="relative my-auto w-[66%]">
            <div class="absolute left-0 top-1/2 z-20 flex h-[60px] w-[60px] -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full bg-primary text-xl font-extrabold text-white shadow-sm">
              1
            </div>
            <div class="flex flex-col overflow-hidden bg-white shadow-xl dark:bg-[#0B0C11] dark:shadow-none">
              <div class="flex-1 overflow-hidden [&_img]:!block [&_img]:!h-[150px] [&_img]:!w-full">
                <Intro.render section={student_welcome_section(@section)} />
              </div>
              <div class="flex items-center justify-end bg-gray-100/50 p-3 dark:bg-black/40">
                <button class="torus-button primary !py-[10px] !px-5 !rounded-[3px] !text-sm flex items-center justify-center">
                  Start Survey
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp preview_table_model(section, ctx) do
    case TableModel.new([section], ctx) do
      {:ok, model} -> model
      _ -> nil
    end
  end

  defp context_dimensions(context) do
    Enum.find(@contexts, fn %{id: id} -> id == normalize_context(context) end) ||
      List.first(@contexts)
  end

  defp modal_scale(context) do
    dims = context_dimensions(context)
    min(0.7, 900 / dims.width)
  end

  defp modal_frame_width(context) do
    dims = context_dimensions(context)
    dims.width * modal_scale(context)
  end

  defp modal_frame_height(context) do
    dims = context_dimensions(context)
    dims.height * modal_scale(context)
  end

  attr :index, :integer, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :active, :boolean, required: true

  defp preview_step_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-6 shrink-0">
      <div class={["flex flex-col text-white", if(!@active, do: "opacity-50")]}>
        <h4 class="mb-[9px] text-[20px] font-bold leading-5 tracking-[0.02px]">{@title}</h4>
        <p class="text-[16px] font-normal leading-[24px] tracking-[0.02px]">{@description}</p>
      </div>
      <div class={[
        "flex h-[60px] w-[60px] shrink-0 self-start items-center justify-center rounded-full text-xl font-extrabold shadow-sm",
        if(@active,
          do: "bg-primary text-white",
          else: "border border-gray-300 bg-white text-gray-400 dark:border-gray-600 dark:bg-black"
        )
      ]}>
        {@index}
      </div>
    </div>
    """
  end

  attr :user_name, :string, required: true
  attr :section, :map, required: true

  defp preview_top_bar(assigns) do
    assigns =
      assigns
      |> assign(:logo_src, Branding.brand_logo_url(assigns.section))
      |> assign(:logo_src_dark, Branding.brand_logo_url_dark(assigns.section))

    ~H"""
    <div class="h-14 border-b border-[#0F0D0F]/5 bg-delivery-header px-6 dark:border-slate-600 dark:bg-delivery-instructor-dashboard-header dark:text-white">
      <div class="flex h-full items-center justify-between">
        <div class="flex items-center gap-3">
          <img class="max-h-8 max-w-[10rem] dark:hidden" src={@logo_src} alt="logo" />
          <img class="hidden max-h-8 max-w-[10rem] dark:block" src={@logo_src_dark} alt="logo" />
        </div>
        <div class="flex items-center gap-3">
          <div class="text-sm font-medium text-[#353740] dark:text-white">{@user_name}</div>
          <div class="flex h-8 w-8 items-center justify-center rounded-full bg-white/85 text-[#353740] dark:bg-white/10 dark:text-white">
            <i class="fa-solid fa-user text-sm"></i>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp preview_section(section) do
    section
    |> Map.put(:start_date, section.start_date || ~U[2025-01-01 00:00:00Z])
    |> Map.put(:end_date, section.end_date || ~U[2025-12-31 00:00:00Z])
    |> Map.put(:progress, Map.get(section, :progress, 72))
    |> Map.put(:instructors, Map.get(section, :instructors, [%{name: "Preview Instructor"}]))
  end

  defp student_welcome_section(section) do
    section
    |> Map.put(:contains_explorations, true)
    |> Map.put(:required_survey_resource_id, Map.get(section, :required_survey_resource_id) || -1)
  end

  defp normalize_context(context) when context in [:my_course, :course_picker, :student_welcome],
    do: context

  defp normalize_context(_), do: :my_course

  defp context_id(:my_course), do: "my-course"
  defp context_id(:course_picker), do: "course-picker"
  defp context_id(:student_welcome), do: "student-welcome"

  defp modal_title(:student_welcome), do: "Student Course Introduction"
  defp modal_title(:my_course), do: "My Courses"
  defp modal_title(:course_picker), do: "Course Picker"
  defp modal_title(_), do: "Student My Courses"

  defp has_previous_context?(:student_welcome), do: false
  defp has_previous_context?(:my_course), do: true
  defp has_previous_context?(:course_picker), do: true
  defp has_previous_context?(_), do: false

  defp has_next_context?(:student_welcome), do: true
  defp has_next_context?(:my_course), do: true
  defp has_next_context?(:course_picker), do: false
  defp has_next_context?(_), do: false

  defp preview_user_name(ctx) do
    user_name =
      case ctx do
        %{user: %{given_name: name}} when is_binary(name) and name != "" -> name
        _ -> nil
      end

    author_name =
      case ctx do
        %{author: %{given_name: name}} when is_binary(name) and name != "" -> name
        _ -> nil
      end

    user_name || author_name || "Student"
  end
end
