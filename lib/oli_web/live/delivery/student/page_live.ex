defmodule OliWeb.Delivery.Student.PageLive do
  use OliWeb, :live_view

  on_mount {OliWeb.LiveSessionPlugs.InitPage, :page_context}
  on_mount {OliWeb.LiveSessionPlugs.InitPage, :previous_next_index}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_view?, true)}
  end

  def render(%{view: :page} = assigns) do
    ~H"""
    <div class="flex pb-20 flex-col items-center gap-15 flex-1">
      <div class="flex flex-col items-center w-full">
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
end
