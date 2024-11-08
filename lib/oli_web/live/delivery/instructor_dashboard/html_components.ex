defmodule OliWeb.Delivery.InstructorDashboard.HTMLComponents do
  use Phoenix.Component

  alias OliWeb.Components.Modal
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  def view_example_student_progress_modal(assigns) do
    ~H"""
    <OliWeb.Components.Modal.modal
      id="student_progress_calculation_modal"
      class="mx-52"
      header_class="flex items-start justify-between pl-[100px] pr-[120px] pt-[27px] pb-4 border-b border-[#E8E8E8] dark:bg-[#0D0C0F]"
      body_class="border-[#3e3f44] pl-[100px] pr-[120px] pb-[50px] pt-[30px] dark:bg-[#0D0C0F]"
    >
      <:title>Student Progress Calculation</:title>
      <div class="dark:text-white text-base">
        <div class="w-[797px] font-bold mb-5">
          Lesson Page Progress
        </div>
        <ul class="flex-col justify-start items-start gap-[16px] inline-flex list-disc list-inside ml-[15px]">
          <li>
            <div class="mb-2">
              <.view_example_bullet_entry entry="Practice Pages with Activities">
                Students achieve 100% progress if they have <span class="font-bold">attempted</span>
                every activity on that page at least once.
              </.view_example_bullet_entry>
            </div>
            <.view_example_container id="1">
              <div class="inset-0 flex justify-center items-center pt-5 pb-10">
                <div class="ml-20 mr-16">
                  <span class="font-medium">If a page has</span>
                  <span class="font-bold">5 activities</span>
                  <span class="font-medium">, and a</span>
                  <span class="font-bold">student completes only 1,</span>
                  <span class="font-medium">the</span>
                  <span class="font-bold">progress for that page is 20%.</span>
                </div>
              </div>
            </.view_example_container>
          </li>
          <li>
            <.view_example_bullet_entry entry="Practice Pages without Activities">
              Students achieve 100% progress if they have <span class="font-bold">visited</span>
              the page at least once.
            </.view_example_bullet_entry>
          </li>
          <li>
            <span class="font-bold">
              Scored Assignments:
            </span>
            <span class="font-medium">
              Students achieve 100% progress on scored assignments if they
              <span class="font-bold">submit</span>
              at least one attempt.
            </span>
          </li>
          <li>
            <span class="font-bold">
              Surveys:
            </span>
            <span class="font-medium">
              Survey questions <span class="font-bold">do not contribute</span> to student progress.
            </span>
          </li>
        </ul>
        <div class="mt-8">
          <div class="self-stretch font-bold mb-5">
            Average Progress
          </div>
          <div class="flex-col justify-start items-start gap-[16px] inline-flex list-disc list-inside">
            <div class="self-stretch font-medium">
              The calculation logic for course progress is based on averaging the completion percentages of individual lesson pages within a container (like a module or unit).
            </div>
            <ul class="list-disc list-inside ml-[15px] flex gap-[16px] flex-col">
              <li class="self-stretch font-medium">
                Each page is either <span class="font-bold">fully complete (1), partially complete (e.g., 0.5)</span>, or <span class="font-bold">not complete (0)</span>.
              </li>
              <li>
                <div class="self-stretch flex-col justify-start items-start flex gap-[14px]">
                  <div class="self-stretch pr-[13px] justify-start items-center">
                    <span class="font-medium">
                      To calculate the progress of a module or unit, add the progress values of all pages within it and divide by the total number of pages.
                    </span>
                  </div>
                  <%!-- Blue Container 2 --%>
                  <.view_example_container id="2">
                    <div class="inset-0 flex justify-center items-center pt-5 pb-10">
                      <div class="ml-20 mr-16 flex flex-col items-start gap-[16px]">
                        <%!-- Start Unit 1 --%>
                        <div class="flex-col justify-start gap-3 inline-flex">
                          <.view_example_blue_item content="Unit 1 - 83.3%" />
                          <ul class="inline-flex flex-col gap-3">
                            <li class="self-stretch list-disc list-inside ml-[15px]">
                              <.view_example_bullet_entry entry="Pages">
                                1, 2, 3 (all 100% = 1), 4 (100% = 1), 5 (50% = 0.5), 6 (50% = 0.5)
                              </.view_example_bullet_entry>
                            </li>
                            <li class="self-stretch list-disc list-inside ml-[15px]">
                              <.view_example_bullet_entry entry="Calculation">
                                (1+1+1+1+0.5+0.5)/6 = 83.3%
                              </.view_example_bullet_entry>
                            </li>
                            <%!-- Start Module 1 --%>
                            <li class="flex flex-col gap-[16px] list-disc list-inside ml-[15px]">
                              <div class="h-[90px] flex-col justify-start gap-3 inline-flex">
                                <.view_example_blue_item content="Module 1 - 100%" />
                                <ul class="inline-flex flex-col gap-3">
                                  <li class="self-stretch list-disc list-inside ml-[15px]">
                                    <.view_example_bullet_entry entry="Pages">
                                      1, 2, 3 (all 100% = 1).
                                    </.view_example_bullet_entry>
                                  </li>
                                  <li class="self-stretch list-disc list-inside ml-[15px]">
                                    <.view_example_bullet_entry entry="Calculation">
                                      (1+1+1)/3 = 1 or 100%
                                    </.view_example_bullet_entry>
                                  </li>
                                </ul>
                              </div>
                              <%!-- End Module 1 --%>
                              <%!-- Start Module 2 --%>
                              <div class="h-[90px] flex-col justify-start gap-3 inline-flex">
                                <.view_example_blue_item content="Module 2 - 66%" />
                                <ul class="inline-flex flex-col gap-3">
                                  <li class="self-stretch list-disc list-inside ml-[15px]">
                                    <.view_example_bullet_entry entry="Pages">
                                      4 (100% = 1), 5 (50% = 0.5), 6 (50% = 0.5).
                                    </.view_example_bullet_entry>
                                  </li>
                                  <li class="self-stretch list-disc list-inside ml-[15px]">
                                    <.view_example_bullet_entry entry="Calculation">
                                      (1+0.5+0.5)/3 = 0.6667 or 66%
                                    </.view_example_bullet_entry>
                                  </li>
                                </ul>
                              </div>
                              <%!-- End Module 2 --%>
                            </li>
                          </ul>
                        </div>
                        <%!-- End Unit 1 --%>
                        <%!-- Start Unit 2 --%>
                        <div class="flex-col justify-start gap-3 inline-flex">
                          <.view_example_blue_item content="Unit 2 - 12.5%" />
                          <ul class="inline-flex flex-col gap-3">
                            <li class="self-stretch list-disc list-inside ml-[15px]">
                              <.view_example_bullet_entry entry="Pages">
                                7 (0% = 0), 8 (50% = 0.5), 9 (0% = 0), 10 (0% = 0).
                              </.view_example_bullet_entry>
                            </li>
                            <li class="self-stretch list-disc list-inside ml-[15px]">
                              <.view_example_bullet_entry entry="Calculation">
                                (0+0.5+0+0)/4 = 0.125 or 12.5%
                              </.view_example_bullet_entry>
                            </li>
                          </ul>
                        </div>
                        <%!-- End Unit 2 --%>
                        <%!-- Start Overall --%>
                        <div class="flex-col justify-start gap-3 inline-flex">
                          <.view_example_blue_item content="Overall Course Progress - 55%" />
                          <ul class="inline-flex flex-col gap-3">
                            <li class="self-stretch list-disc list-inside ml-[15px]">
                              <.view_example_bullet_entry entry="All Pages Combined">
                                Pages 1-10
                              </.view_example_bullet_entry>
                            </li>
                            <li class="self-stretch list-disc list-inside ml-[15px]">
                              <.view_example_bullet_entry entry="Calculation">
                                (1+1+1+1+0.5+0.5+0+0.5+0+0)/10 = 0.55 or 55%
                              </.view_example_bullet_entry>
                            </li>
                          </ul>
                        </div>
                        <%!-- End Overall --%>
                      </div>
                    </div>
                  </.view_example_container>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </OliWeb.Components.Modal.modal>
    """
  end

  attr :title, :string, required: true
  attr :show, :boolean, default: false

  def student_progress_label(assigns) do
    ~H"""
    <div class="inline-flex gap-2 items-center relative cursor-auto" onclick="event.stopPropagation()">
      <div
        onclick="event.stopPropagation()"
        id="student_progress_tooltip"
        class="absolute -translate-y-[34px] -translate-x-[140px] min-w-max w-full pb-[27px] z-10 hidden"
        phx-click-away={JS.hide()}
        phx-hook="HoverAway"
        mouse-leave-js={
          JS.hide(transition: {"ease-out duration-300", "opacity-100", "opacity-0"}, time: 300)
        }
      >
        <div class="px-4 py-2 bg-white dark:bg-[#0d0c0f] rounded-md shadow border border-[#3a3740] justify-start items-center inline-flex font-normal z-10">
          <div class="grow shrink basis-0">
            <span style="text-[#353740] dark:text-[#eeebf5] text-sm leading-normal">
              This is an estimate of student progress.<br />
              <button
                phx-hook="ClickExecJS"
                click-exec-js={
                  Modal.show_modal("student_progress_calculation_modal")
                  |> JS.hide(to: "#student_progress_tooltip")
                }
                id="student_progress_tooltip_link"
                class="text-[#0165da] text-sm dark:text-white underline font-bold"
              >
                Learn more.
              </button>
            </span>
          </div>
        </div>
      </div>
      <button
        xphx-mouseover={JS.show(to: "#student_progress_tooltip")}
        class="max-w-min border border-transparent"
      >
        <Icons.info />
      </button>
    </div>
    <%= @title %>
    """
  end

  attr :id, :string, required: true
  slot :inner_block, required: true

  defp view_example_container(assigns) do
    ~H"""
    <div class="mb-2 w-full">
      <div
        id={"view_example_outter_button_#{@id}"}
        phx-click={JS.show(to: "#view_example_container_#{@id}") |> JS.hide()}
        class="cursor-pointer translate-x-[12px] translate-y-[5px] max-w-fit px-3 py-1 bg-[#ced9f2] rounded-3xl shadow flex-col justify-start items-start inline-flex"
      >
        <div class="justify-center items-center gap-1.5 inline-flex">
          <div class="text-black text-sm font-normal">View Example</div>
          <Icons.chevron_down class="fill-black dark:fill-dark" />
        </div>
      </div>
      <div
        id={"view_example_container_#{@id}"}
        class="hidden px-3 py-1.5 bg-[#ced9f2]/30 rounded-xl shadow flex-col justify-start items-start inline-flex"
      >
        <div
          id={"view_example_inner_button_#{@id}"}
          phx-click={
            JS.show(to: "#view_example_outter_button_#{@id}")
            |> JS.hide(to: "#view_example_container_#{@id}")
          }
          class="max-w-fit px-3 py-1 bg-[#ced9f2] rounded-3xl shadow flex-col justify-start items-start inline-flex"
        >
          <div class="justify-center items-center gap-1.5 inline-flex">
            <div class="text-black text-sm font-normal">View Example</div>
            <Icons.chevron_down class="fill-black dark:fill-dark -rotate-180" />
          </div>
        </div>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  attr :entry, :string, required: true
  slot :inner_block, required: true

  defp view_example_bullet_entry(assigns) do
    ~H"""
    <span class="text-[#383a44] text-base font-bold dark:text-white"><%= @entry %>:</span>
    <span class="text-[#383a44] text-base font-medium dark:text-white">
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  attr :content, :string, required: true

  defp view_example_blue_item(assigns) do
    ~H"""
    <div class="self-stretch text-[#0165da] text-base font-bold dark:text-white">
      <%= @content %>
    </div>
    """
  end
end
