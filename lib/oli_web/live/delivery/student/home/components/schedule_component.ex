defmodule OliWeb.Delivery.Student.Home.Components.ScheduleComponent do
  use OliWeb, :live_component

  alias OliWeb.Common.{SessionContext, FormatDateTime}
  alias OliWeb.Components.Delivery.Student
  alias OliWeb.Icons
  alias OliWeb.Delivery.Student.Utils

  def mount(socket) do
    {:ok,
     socket
     |> assign(expanded_items: [])}
  end

  def handle_event("expand_item", %{"item_id" => item_id}, socket) do
    expanded_items =
      if item_id in socket.assigns.expanded_items do
        List.delete(socket.assigns.expanded_items, item_id)
      else
        [item_id | socket.assigns.expanded_items]
      end

    {:noreply, assign(socket, expanded_items: expanded_items)}
  end

  attr(:ctx, SessionContext, required: true)
  attr(:grouped_agenda_resources, :any, required: true)
  attr(:section_start_date, :string, required: true)
  attr(:section_slug, :string, required: true)
  attr(:expanded_items, :list, default: [])

  def render(assigns) do
    ~H"""
    <div class="justify-start items-center gap-1 inline-flex self-stretch">
      <div class="text-base font-normal tracking-tight grow">
        <%= for {{week, scheduled_groups}, week_idx} <- Enum.with_index(@grouped_agenda_resources, 1) do %>
          <% week_range =
            if week != {nil, nil},
              do: Utils.week_range(week, @section_start_date) %>
          <div
            id={"schedule_week_#{week_idx}"}
            class="flex self-stretch h-fit flex-col justify-start items-start gap-3.5 pb-7"
          >
            <div :if={week_range} class="flex self-stretch justify-between items-baseline">
              <div role="schedule_title" class="dark:text-white text-lg font-bold tracking-tight">
                <%= this_or_next_week(week_range) %>
              </div>
              <div role="schedule_date_range" class="dark:text-white text-sm font-bold tracking-tight">
                <%= Phoenix.HTML.raw(week_range(week_range)) %>
              </div>
            </div>
            <div class="flex flex-col w-full h-fit gap-2.5">
              <.schedule_item
                :for={{item, item_idx} <- Enum.with_index(scheduled_groups, 1)}
                id={"schedule_item_#{week_idx}_#{item_idx}"}
                item={item}
                ctx={@ctx}
                section_slug={@section_slug}
                expanded={item.id in @expanded_items}
                target={@myself}
              />
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :item, :any, required: true
  attr :ctx, :map, required: true
  attr :section_slug, :string, required: true
  attr :target, :any, required: true
  attr :expanded, :boolean, default: false

  defp schedule_item(%{item: item} = assigns) when length(item.resources) > 1 do
    ~H"""
    <% completed = Enum.all?(@item.resources, &(&1.progress == 100)) %>

    <div
      id={@id}
      class={[
        item_bg_color(completed),
        "flex h-fit px-2.5 py-3.5 rounded-xl border flex-col justify-start items-start"
      ]}
    >
      <div class="self-stretch justify-between items-start flex pl-2">
        <div class="grow shrink basis-0 self-stretch flex-col justify-start items-start gap-2.5 flex">
          <div role="container_label" class="justify-start items-start gap-2 flex uppercase">
            <div class="dark:text-white text-opacity-60 text-xs font-bold whitespace-nowrap">
              <%= @item.unit_label %>
            </div>

            <div :if={@item.module_id} class="flex items-center gap-2">
              <div class="dark:text-white text-opacity-60 text-xs font-bold">•</div>
              <div class="dark:text-white text-opacity-60 text-xs font-bold whitespace-nowrap">
                <%= @item.module_label %>
              </div>
            </div>
          </div>
          <div role="title" class="self-stretch pb-2.5 justify-start items-start gap-2.5 flex">
            <div class="grow shrink basis-0 dark:text-white text-opacity-90 text-lg font-semibold">
              <%= @item.container_title %>
            </div>
          </div>
        </div>
        <Student.resource_type type={:lesson} />
      </div>

      <.schedule_item_details
        item_id={@item.id}
        item_type={:expandable}
        completed={Enum.all?(@item.resources, &(&1.progress == 100))}
        resources={@item.resources}
        ctx={@ctx}
        expanded={@expanded}
        target={@target}
        section_slug={@section_slug}
      />
    </div>
    """
  end

  defp schedule_item(assigns) do
    assigns = Map.put(assigns, :resource, hd(assigns.item.resources))

    ~H"""
    <% completed = @resource.progress == 100 %>
    <% assignment = @resource.graded and @resource.purpose != :application %>

    <.link
      id={@id}
      href={
        Utils.lesson_live_path(@section_slug, @resource.resource.revision_slug,
          request_path: ~p"/sections/#{@section_slug}"
        )
      }
      class="text-black hover:text-black hover:no-underline"
    >
      <div class={[
        item_bg_color(completed),
        maybe_assignment_left_bar(assignment),
        "flex h-fit px-2.5 py-3.5 rounded-xl border flex-col justify-start items-start hover:cursor-pointer"
      ]}>
        <div class="self-stretch justify-between items-start flex pl-2">
          <div class="grow shrink basis-0 self-stretch flex-col justify-start items-start gap-2.5 flex">
            <div role="container_label" class="justify-start items-start gap-2 flex uppercase">
              <div class="dark:text-white text-opacity-60 text-xs font-bold whitespace-nowrap">
                <%= @item.unit_label %>
              </div>

              <div :if={@item.module_id} class="flex items-center gap-2">
                <div class="dark:text-white text-opacity-60 text-xs font-bold">•</div>
                <div class="dark:text-white text-opacity-60 text-xs font-bold whitespace-nowrap">
                  <%= @item.module_label %>
                </div>
              </div>
            </div>
            <div role="title" class="self-stretch pb-2.5 justify-start items-start gap-2.5 flex">
              <div class="grow shrink basis-0 dark:text-white text-opacity-90 text-lg font-semibold">
                <%= @resource.resource.title %>
              </div>
            </div>
          </div>
          <Student.resource_type type={Student.type_from_resource(@resource)} />
        </div>

        <.schedule_item_details
          item_id={@item.id}
          item_type={:simple}
          completed={@resource.progress == 100}
          resources={[@resource]}
          ctx={@ctx}
          target={@target}
          section_slug={@section_slug}
        />
      </div>
    </.link>
    """
  end

  defp item_bg_color(true = _completed),
    do:
      "bg-black/[.07] hover:bg-black/[.1] border border-white/[.1] dark:bg-white/[.02] dark:hover:bg-white/[.06] dark:border-white/[0.06] dark:hover:border-white/[0.02]"

  defp item_bg_color(false = _completed),
    do:
      "bg-black/[.1] hover:bg-black/[.2] border border-white/[.6] dark:bg-white/[.08] dark:hover:bg-white/[.12] dark:border-black hover:!border-transparent"

  defp maybe_assignment_left_bar(true),
    do:
      "relative overflow-hidden z-0 before:content-[''] before:absolute before:left-0 before:top-0 before:w-0.5 before:h-full before:bg-checkpoint before:z-10"

  defp maybe_assignment_left_bar(_), do: ""

  attr :item_id, :string, required: true
  attr :item_type, :atom, required: true
  attr :completed, :boolean, required: true
  attr :resources, :list, required: true
  attr :ctx, :map, required: true
  attr :target, :any, required: true
  attr :expanded, :boolean, default: false
  attr :section_slug, :string, required: true

  # Graded pages with existing attempts for simple schedule items
  defp schedule_item_details(
         %{
           item_type: :simple,
           resources: [%{graded: true, resource_attempt_count: attempt_count} = resource]
         } =
           assigns
       )
       when attempt_count > 0 do
    assigns = Map.put(assigns, :resource, resource)

    ~H"""
    <div role="details" class="pt-2 pb-1 px-1 flex self-stretch justify-between gap-5">
      <div class="flex justify-start items-center gap-5">
        <div
          :if={!is_nil(@resource.raw_avg_score) and @resource.last_attempt[:state] != :active}
          class="py-px justify-end items-start gap-2.5 flex"
        >
          <div class="text-green-700 dark:text-green-500 flex justify-end items-center gap-1">
            <div class="w-4 h-4 relative"><Icons.star /></div>
            <div class="text-sm font-semibold tracking-tight">
              <%= Utils.parse_score(@resource.raw_avg_score[:score]) %>
            </div>
            <div class="text-sm font-semibold tracking-widest">
              /
            </div>
            <div class="text-sm font-semibold tracking-tight">
              <%= Utils.parse_score(@resource.raw_avg_score[:out_of]) %>
            </div>
          </div>
        </div>

        <div class="py-px justify-end items-start gap-2.5 flex">
          <div class="text-right dark:text-white text-opacity-60 text-sm font-semibold">
            Attempt <%= @resource.resource_attempt_count %> of <%= max_attempts(
              @resource.effective_settings
            ) %>
          </div>
        </div>
      </div>
      <%= if @resource.last_attempt[:state] == :active do %>
        <div class="justify-end items-end gap-1 flex ml-auto">
          <div :if={attempt_expires?(@resource)} class="justify-end items-end gap-1 flex ml-auto">
            <div class="dark:text-white text-opacity-60 text-xs font-semibold ">
              Time Remaining:
            </div>
            <div role="countdown" class="dark:text-white text-xs font-semibold">
              <%= effective_attempt_expiration_date(@resource) |> Utils.format_time_remaining() %>
            </div>
          </div>
        </div>
      <% else %>
        <div :if={@resource.last_attempt} class="justify-end items-end gap-1 flex ml-auto">
          <div class="dark:text-white text-opacity-60 text-xs font-semibold ">
            Last Submitted:
          </div>
          <div class="dark:text-white text-xs font-semibold">
            <%= FormatDateTime.to_formatted_datetime(
              @resource.last_attempt[:date_submitted],
              @ctx,
              "{WDshort} {Mshort} {D}, {YYYY}"
            ) %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp schedule_item_details(assigns) do
    ~H"""
    <div role="details" class="w-full h-full flex flex-col items-stretch gap-5 relative">
      <.schedule_group_content
        :if={@item_type == :expandable}
        item_id={@item_id}
        target={@target}
        expanded={@expanded}
        completed={@completed}
        resources={@resources}
        section_slug={@section_slug}
      />

      <div class="pr-2 pl-1 self-end">
        <div class="flex items-end gap-1">
          <div class="text-right dark:text-white text-opacity-90 text-xs font-semibold">
            <%= if @completed do %>
              Completed
            <% else %>
              <%= if is_nil(hd(@resources).effective_settings),
                do:
                  Utils.days_difference(
                    hd(@resources).end_date,
                    grouped_scheduling_type(@resources),
                    @ctx
                  ),
                else:
                  Utils.coalesce(hd(@resources).effective_settings.end_date, hd(@resources).end_date)
                  |> Utils.coalesce(hd(@resources).effective_settings.start_date)
                  |> Utils.days_difference(grouped_scheduling_type(@resources), @ctx) %>
            <% end %>
          </div>
          <Icons.check :if={@completed} progress={1.0} />
        </div>
      </div>
    </div>
    """
  end

  _docp = """
  If all the resources have a :read_by scheduling type, the group is considered to be :read_by,
  so the label will end up being "Suggested by"
  """

  defp grouped_scheduling_type(scheduled_section_resources) do
    scheduling_types =
      Enum.map(scheduled_section_resources, fn scheduled_section_resource ->
        if !is_nil(scheduled_section_resource.effective_settings),
          do: scheduled_section_resource.effective_settings.scheduling_type,
          else: scheduled_section_resource.resource.scheduling_type
      end)

    if Enum.all?(scheduling_types, &(&1 == :read_by)), do: :read_by, else: :due_by
  end

  attr :item_id, :string, required: true
  attr :target, :any, required: true
  attr :expanded, :boolean, required: true
  attr :completed, :boolean, required: true
  attr :resources, :list, required: true
  attr :section_slug, :string, required: true

  defp schedule_group_content(assigns) do
    ~H"""
    <div role="group" class="w-full self-start">
      <button
        phx-click="expand_item"
        phx-value-item_id={@item_id}
        phx-target={@target}
        class="hover:cursor-pointer absolute top-3.5 left-3 z-10"
      >
        <div class={[
          if(@completed,
            do: "bg-black/[0.1] dark:bg-white/[0.1]",
            else: "bg-[#5798f8] dark:bg-[#0F6CF5]"
          ),
          "flex px-2 py-0.5 rounded-xl shadow tracking-tight gap-2 items-center align-center"
        ]}>
          <div role="count" class="pl-1 justify-start items-center gap-2.5 flex">
            <div class="dark:text-white text-xs font-semibold">
              <%= length(@resources) %> pages
            </div>
          </div>
          <div class="w-4 h-4">
            <Icons.chevron_down width="16" height="16" class={if @expanded, do: "rotate-180"} />
          </div>
        </div>
      </button>
      <div
        :if={@expanded}
        class="w-full h-full bg-white/[.15] dark:bg-[#030105]/[.15] rounded-md flex-col justify-start items-start gap-2.5 inline-flex"
      >
        <div class="self-stretch pt-12 flex-col justify-start items-start gap-0.5 flex">
          <.link
            :for={resource <- Enum.sort_by(@resources, & &1.resource.numbering_index)}
            href={
              Utils.lesson_live_path(@section_slug, resource.resource.revision_slug,
                request_path: ~p"/sections/#{@section_slug}"
              )
            }
            class="w-full text-black hover:text-black dark:text-white dark:hover:text-white hover:no-underline"
          >
            <% resource_completed = resource.progress == 100 %>
            <div
              role="group_item"
              class="w-full flex self-stretch pl-7 pr-4 py-2.5 rounded-lg justify-start items-start gap-5 hover:bg-[#000000]/5 dark:hover:bg-[#FFFFFF]/5 hover:font-medium hover:cursor-pointer"
            >
              <div class="grow shrink h-auto justify-start items-start gap-5 flex">
                <div class="justify-start items-start gap-5 flex">
                  <div class="w-5 h-5 flex-col justify-center items-center inline-flex">
                    <div class="justify-center items-center inline-flex">
                      <Icons.check :if={resource_completed} progress={1.0} />
                    </div>
                  </div>
                  <div class="w-6 justify-start items-center gap-2.5 flex">
                    <div class="grow shrink basis-0 opacity-60 text-xs font-semibold capitalize">
                      <%= resource.resource.numbering_index %>
                    </div>
                  </div>
                </div>
                <div class="grow shrink h-auto justify-start items-start gap-2.5 flex">
                  <div class={[
                    if(resource_completed, do: "opacity-60", else: "opacity-90"),
                    "text-base font-normal whitespace-normal"
                  ]}>
                    <%= resource.resource.title %>
                  </div>
                </div>
              </div>
              <Student.duration_in_minutes
                duration_minutes={resource.duration_minutes}
                graded={resource.graded}
              />
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp max_attempts(%{max_attempts: 0}), do: "∞"
  defp max_attempts(%{max_attempts: max_attempts}), do: max_attempts

  defp this_or_next_week(week_range) do
    {week_start, _} = week_range

    case Date.beginning_of_week(Oli.DateTime.utc_now(), :sunday) do
      ^week_start ->
        "This Week"

      _ ->
        "Next Week"
    end
  end

  defp week_range({week_start, week_end} = range) do
    make_sup = &"<sup>#{&1}</sup>"
    maybe_show_year = if week_start.year != week_end.year, do: " {YYYY}", else: ""

    [start_ordinal, end_ordinal] =
      range
      |> Tuple.to_list()
      |> Enum.map(fn date -> date.day |> ordinal_indicator() |> make_sup.() end)

    Timex.format!(week_start, "{Mshort} {D}#{start_ordinal}#{maybe_show_year}") <>
      " - " <> Timex.format!(week_end, "{Mshort} {D}#{end_ordinal} {YYYY}")
  end

  defp ordinal_indicator(number) when number in [11, 12, 13], do: "th"
  defp ordinal_indicator(number) when rem(number, 10) == 1, do: "st"
  defp ordinal_indicator(number) when rem(number, 10) == 2, do: "nd"
  defp ordinal_indicator(number) when rem(number, 10) == 3, do: "rd"
  defp ordinal_indicator(_number), do: "th"

  defp attempt_expires?(resource) do
    Utils.attempt_expires?(
      resource.last_attempt[:state],
      resource.effective_settings.time_limit,
      resource.effective_settings.late_submit,
      resource.effective_settings.end_date
    )
  end

  defp effective_attempt_expiration_date(resource) do
    Utils.effective_attempt_expiration_date(
      resource.last_attempt[:inserted_at],
      resource.effective_settings.time_limit,
      resource.effective_settings.late_submit,
      resource.effective_settings.end_date
    )
  end
end
