defmodule OliWeb.Delivery.Student.LessonLive do
  use OliWeb, :live_view

  on_mount {OliWeb.LiveSessionPlugs.InitPage, :page_context}
  on_mount {OliWeb.LiveSessionPlugs.InitPage, :previous_next_index}

  alias Oli.Delivery.Sections
  alias OliWeb.Common.FormatDateTime

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(%{view: :page} = assigns) do
    ~H"""
    <div class="flex pb-20 flex-col items-center gap-15 flex-1">
      <div class="flex flex-col items-center w-full">
        <.scored_page_banner :if={@revision.graded} />
        <div class="w-[720px] pt-20 pb-10 flex-col justify-start items-center gap-10 inline-flex">
          <.page_header
            revision={@revision}
            page_context={@page_context}
            ctx={@ctx}
            index={@current_page["index"]}
            container_label={get_container_label(@current_page["id"], @section)}
          />
          <div phx-update="ignore" id="eventIntercept" class="content">
            <%= raw(@html) %>
          </div>
        </div>
      </div>
    </div>

    <script>
      window.userToken = "<%= @user_token %>";
    </script>
    <script>
      OLI.initActivityBridge('eventIntercept');
    </script>
    <script :for={script <- @scripts} type="text/javascript" src={"/js/#{script}"}>
    </script>
    """
  end

  # As we implement more scenarios we can add more clauses to this function depending on the :view key.
  def render(assigns) do
    ~H"""
    <div></div>
    """
  end

  def scored_page_banner(assigns) do
    ~H"""
    <div class="w-full lg:px-20 px-40 py-9 bg-orange-500 bg-opacity-10 flex flex-col justify-center items-center gap-2.5">
      <div class="px-3 py-1.5 rounded justify-start items-start gap-2.5 flex">
        <div class="dark:text-white text-sm font-bold uppercase tracking-wider">
          Scored Activity
        </div>
      </div>
      <div class="max-w-[720px] w-full mx-auto opacity-90 dark:text-white text-sm font-normal leading-6">
        You can start or stop at any time, and your progress will be saved. When you submit your answers using the Submit button, it will count as an attempt. So make sure you have answered all the questions before submitting.
      </div>
    </div>
    """
  end

  attr :revision, Oli.Resources.Revision
  attr :page_context, Oli.Delivery.Page.PageContext
  attr :ctx, OliWeb.Common.SessionContext
  attr :index, :string
  attr :container_label, :string
  attr :has_assignments?, :boolean

  def page_header(assigns) do
    ~H"""
    <div class="flex-col justify-start items-start gap-9 flex w-full">
      <div class="flex-col justify-start items-start gap-3 flex w-full">
        <div class="self-stretch flex-col justify-start items-start flex">
          <div class="self-stretch justify-between items-center inline-flex">
            <div class="grow shrink basis-0 self-stretch justify-start items-center gap-3 flex">
              <div class="opacity-50 dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider">
                <%= @container_label %>
              </div>

              <div :if={@revision.graded} class="w-px self-stretch opacity-40 bg-black dark:bg-white">
              </div>
              <div :if={@revision.graded} class="justify-start items-center gap-1.5 flex">
                <div class="w-[18px] h-[18px] relative">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="18"
                    height="18"
                    viewBox="0 0 18 18"
                    fill="none"
                    role="flag icon"
                  >
                    <path
                      d="M3.75 15.75V3H10.5L10.8 4.5H15V12H9.75L9.45 10.5H5.25V15.75H3.75Z"
                      fill="#F68E2E"
                    />
                  </svg>
                </div>
                <div class="opacity-50 dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider">
                  Graded Page
                </div>
              </div>
            </div>
            <div
              :if={@page_context.activities != %{}}
              class="px-2 py-1 bg-black bg-opacity-10 dark:bg-white dark:bg-opacity-10 rounded-xl shadow justify-start items-center gap-1 flex"
            >
              <div class="dark:text-white text-[10px] font-normal font-['Open Sans']">
                Assignment requirement
              </div>
            </div>
          </div>
          <div class="self-stretch justify-start items-start gap-2.5 inline-flex">
            <div class="opacity-50 dark:text-white text-[38px] font-bold font-['Open Sans']">
              <%= @index %>.
            </div>
            <div class="grow shrink basis-0 dark:text-white text-[38px] font-bold font-['Open Sans']">
              <%= @revision.title %>
            </div>
          </div>
        </div>
        <div class="justify-start items-center gap-3 inline-flex">
          <div class="opacity-50 justify-start items-center gap-1.5 flex">
            <div class="justify-end items-center gap-1 flex">
              <div class="w-[18px] h-[18px] relative opacity-80">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="18"
                  height="18"
                  viewBox="0 0 18 18"
                  fill="none"
                  role="time icon"
                >
                  <g opacity="0.8">
                    <path
                      class="fill-black dark:fill-white"
                      d="M11.475 12.525L12.525 11.475L9.75 8.7V5.25H8.25V9.3L11.475 12.525ZM9 16.5C7.9625 16.5 6.9875 16.3031 6.075 15.9094C5.1625 15.5156 4.36875 14.9813 3.69375 14.3063C3.01875 13.6313 2.48438 12.8375 2.09063 11.925C1.69688 11.0125 1.5 10.0375 1.5 9C1.5 7.9625 1.69688 6.9875 2.09063 6.075C2.48438 5.1625 3.01875 4.36875 3.69375 3.69375C4.36875 3.01875 5.1625 2.48438 6.075 2.09063C6.9875 1.69688 7.9625 1.5 9 1.5C10.0375 1.5 11.0125 1.69688 11.925 2.09063C12.8375 2.48438 13.6313 3.01875 14.3063 3.69375C14.9813 4.36875 15.5156 5.1625 15.9094 6.075C16.3031 6.9875 16.5 7.9625 16.5 9C16.5 10.0375 16.3031 11.0125 15.9094 11.925C15.5156 12.8375 14.9813 13.6313 14.3063 14.3063C13.6313 14.9813 12.8375 15.5156 11.925 15.9094C11.0125 16.3031 10.0375 16.5 9 16.5ZM9 15C10.6625 15 12.0781 14.4156 13.2469 13.2469C14.4156 12.0781 15 10.6625 15 9C15 7.3375 14.4156 5.92188 13.2469 4.75313C12.0781 3.58438 10.6625 3 9 3C7.3375 3 5.92188 3.58438 4.75313 4.75313C3.58438 5.92188 3 7.3375 3 9C3 10.6625 3.58438 12.0781 4.75313 13.2469C5.92188 14.4156 7.3375 15 9 15Z"
                    />
                  </g>
                </svg>
              </div>
              <div class="justify-end items-end gap-0.5 flex">
                <div class="text-right dark:text-white text-xs font-bold font-['Open Sans'] uppercase tracking-wide">
                  <%= @revision.duration_minutes %>
                </div>
                <div class="dark:text-white text-[9px] font-bold font-['Open Sans'] uppercase tracking-wide">
                  min
                </div>
              </div>
            </div>
          </div>
          <div class="justify-start items-start gap-1 flex">
            <div class="opacity-50 dark:text-white text-xs font-normal font-['Open Sans']">Due:</div>
            <div class="dark:text-white text-xs font-normal font-['Open Sans']">
              <%= FormatDateTime.to_formatted_datetime(
                @page_context.effective_settings.end_date,
                @ctx,
                "{WDshort} {Mshort} {D}, {YYYY}"
              ) %>
            </div>
          </div>
        </div>
      </div>
      <div
        :if={@page_context.objectives not in [nil, []]}
        class="flex-col justify-start items-start gap-3 flex w-full"
      >
        <div class="self-stretch justify-start items-start gap-6 inline-flex">
          <div class="opacity-80 dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider">
            Learning objectives
          </div>
          <div class="hidden text-blue-500 text-sm font-semibold font-['Open Sans']">View More</div>
        </div>
        <div
          :for={{objective, index} <- Enum.with_index(@page_context.objectives, 1)}
          class="self-stretch flex-col justify-start items-start flex"
        >
          <div class="self-stretch py-1 justify-start items-start inline-flex">
            <div class="grow shrink basis-0 h-6 justify-start items-start flex">
              <div class="w-[30px] opacity-40 dark:text-white text-xs font-bold font-['Open Sans'] leading-normal">
                L<%= index %>
              </div>
              <div class="grow shrink basis-0 opacity-80 dark:text-white text-sm font-normal font-['Open Sans'] leading-normal">
                <%= objective %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_container_label(page_id, section) do
    container =
      Oli.Delivery.Hierarchy.find_parent_in_hierarchy(
        section.full_hierarchy,
        fn node -> node["resource_id"] == String.to_integer(page_id) end
      )["numbering"]

    Sections.get_container_label_and_numbering(
      %{numbering_level: container["level"], numbering_index: container["index"]},
      section.customizations
    )
  end
end
