defmodule OliWeb.Delivery.Student.PageLive do
  use OliWeb, :live_view

  on_mount {OliWeb.LiveSessionPlugs.InitPage, :page_context}
  on_mount {OliWeb.LiveSessionPlugs.InitPage, :previous_next_index}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_view?, true)}
  end

  def render(%{view: :page} = assigns) do
    ~H"""
    <div class="flex pb-[80px] flex-col items-center gap-[60px] flex-1">
      <div class="flex flex-col items-center self-stretch">
        <.scored_page_banner />
        <div>
          <%!-- PAGE CONTENT --%>
        </div>
      </div>
    </div>
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
    <div class="w-full px-[164px] py-9 bg-orange-500 bg-opacity-10 flex-col justify-center items-center gap-2.5 inline-flex">
      <div class="px-3 py-1.5 rounded-[3px] justify-start items-start gap-2.5 inline-flex">
        <div class="dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-wider">
          Scored Activity
        </div>
      </div>
      <div class="w-[720px] mx-auto opacity-90 dark:text-white text-sm font-normal font-['Open Sans'] leading-[25.20px]">
        You can start or stop at any time, and your progress will be saved. When you submit your answers using the Submit button, it will count as an attempt. So make sure you have answered all the questions before submitting.
      </div>
    </div>
    """
  end
end
