defmodule OliWeb.Workspace.CourseAuthor do
  use OliWeb, :live_view

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias OliWeb.Backgrounds
  alias OliWeb.Common.{Params, SearchInput}
  alias OliWeb.Components.Delivery.Utils
  alias OliWeb.Icons

  import Ecto.Query, warn: false
  import OliWeb.Common.SourceImage
  import OliWeb.Components.Delivery.Layouts

  @default_params %{
    sidebar_expanded: true
  }

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    {:ok, assign(socket, params: decode_params(params), active_workspace: :course_author)}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, params: decode_params(params))}
  end

  @impl Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <div class="dark:bg-[#0F0D0F] bg-[#F3F4F8]">
      <div class="relative flex items-center h-[247px]">
        <div class="absolute top-0 h-full w-full">
          <Backgrounds.instructor_dashboard_header />
        </div>
        <div class="flex-col justify-start items-start gap-[15px] z-10 px-[63px] font-['Open Sans']">
          <div class="flex flex-row items-center gap-3">
            <Icons.growing_bars
              stroke_class="stroke-[#353740] dark:stroke-white"
              width={36}
              height={36}
            />
            <h1 class="text-[#353740] dark:text-white text-[32px] font-bold leading-normal">
              Course Author
            </h1>
          </div>
          <h2 class="text-[#353740] dark:text-white text-base font-normal leading-normal">
            This is a placeholder for ticket MER-3320
          </h2>
        </div>
      </div>

      <div class="flex flex-col items-start mt-[40px] gap-9 py-[60px] px-[63px]">
        <div class="flex flex-col gap-4">
          <h3 class="dark:text-violet-100 text-xl font-bold font-['Open Sans'] leading-normal whitespace-nowrap">
            Some title
          </h3>
          <div class="dark:text-violet-100 text-base font-normal font-['Inter'] leading-normal">
            some text
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp decode_params(params) do
    %{
      sidebar_expanded:
        Params.get_boolean_param(params, "sidebar_expanded", @default_params.sidebar_expanded)
    }
  end
end
