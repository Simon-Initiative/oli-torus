defmodule OliWeb.Delivery.Student.LearnLive do
  use OliWeb, :live_view

  alias Oli.Accounts.User
  alias OliWeb.Common.FormatDateTime
  alias Oli.Delivery.{Hierarchy, Metrics, Sections}
  alias Phoenix.LiveView.JS
  alias Oli.Delivery.Sections.SectionCache
  alias OliWeb.Common.Utils, as: WebUtils
  alias OliWeb.Components.Delivery.Student
  alias OliWeb.Delivery.Student.Utils
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  import Oli.Utils, only: [get_in: 3]

  @default_selected_view :gallery

  @default_module_page_metrics %{
    total_pages_count: 0,
    completed_pages_count: 0,
    total_duration_minutes: 0
  }

  @default_image "/images/course_default.png"
  # this is an optimization to reduce the memory footprint of the liveview process
  @required_keys_per_assign %{
    section:
      {[
         :id,
         :analytics_version,
         :slug,
         :customizations,
         :title,
         :brand,
         :lti_1p3_deployment,
         :contains_discussions,
         :contains_explorations,
         :contains_deliberate_practice,
         :open_and_free
       ], %Sections.Section{}},
    current_user: {[:id, :name, :email], %User{}}
  }

  @page_resource_type_id Oli.Resources.ResourceType.get_id_by_type("page")
  @container_resource_type_id Oli.Resources.ResourceType.get_id_by_type("container")

  def mount(_params, _session, socket) do
    section = socket.assigns.section

    # when updating to Liveview 0.20 we should replace this with assign_async/3
    # https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#assign_async/3
    if connected?(socket),
      do:
        async_calculate_student_metrics_and_enable_slider_buttons(
          self(),
          section,
          socket.assigns[:current_user]
        )

    socket =
      assign(socket,
        active_tab: :learn,
        selected_module_per_unit_resource_id: %{},
        student_end_date_exceptions_per_resource_id: %{},
        student_visited_pages: %{},
        student_progress_per_resource_id: %{},
        student_raw_avg_score_per_page_id: %{},
        student_raw_avg_score_per_container_id: %{},
        page_metrics_per_module_id: %{},
        viewed_intro_video_resource_ids:
          get_viewed_intro_video_resource_ids(
            section.slug,
            socket.assigns.current_user.id
          ),
        assistant_enabled: Sections.assistant_enabled?(section),
        display_props_per_module_id: %{},
        selected_view: @default_selected_view
      )
      |> stream_configure(:units, dom_id: &"units-#{&1["uuid"]}")
      |> stream_configure(:unit_resource_ids, dom_id: &"unit_resource_ids-#{&1["uuid"]}")
      |> stream(:unit_resource_ids, [])
      |> slim_assigns()

    {:ok, socket}
  end

  defp slim_assigns(socket) do
    Enum.reduce(@required_keys_per_assign, socket, fn {assign_name, {required_keys, struct}},
                                                      socket ->
      assign(
        socket,
        assign_name,
        Map.merge(
          struct,
          Map.filter(socket.assigns[assign_name], fn {k, _v} -> k in required_keys end)
        )
      )
    end)
  end

  def handle_params(
        params,
        _uri,
        socket
      ) do
    full_hierarchy = get_or_compute_full_hierarchy(socket.assigns.section)

    send(self(), :gc)

    with selected_view <- get_selected_view(params),
         resource_id <- params["target_resource_id"] do
      {:noreply,
       socket
       |> maybe_assign_selected_view(selected_view)
       |> stream(:units, full_hierarchy["children"], reset: true)
       |> maybe_scroll_to_target_resource(resource_id, full_hierarchy, selected_view)}
    end
  end

  _docp = """
  This assign helper function is responsible for scrolling to the target resource.
  The target can be a unit, a module, a page contained at a unit level, at a module level, or a page contained in a module.
  """

  defp scroll_to_target_resource(socket, resource_id, _full_hierarchy, :outline) do
    case Sections.get_section_resource_with_resource_type(
           socket.assigns.section.slug,
           resource_id
         ) do
      %{resource_type_id: resource_type_id, numbering_level: numbering_level} ->
        resource_type =
          case {resource_type_id, numbering_level} do
            {@container_resource_type_id, 1} -> "unit"
            {@container_resource_type_id, 2} -> "module"
            {@container_resource_type_id, 3} -> "section"
            {@page_resource_type_id, 1} -> "top_level_page"
            {@page_resource_type_id, _} -> "page"
          end

        push_event(socket, "scroll-y-to-target", %{
          id: "#{resource_type}_#{resource_id}",
          offset: 25,
          pulse: true,
          pulse_delay: 500
        })

      _ ->
        socket
    end
  end

  defp scroll_to_target_resource(socket, resource_id, full_hierarchy, :gallery) do
    case Sections.get_section_resource_with_resource_type(
           socket.assigns.section.slug,
           resource_id
         ) do
      %{resource_type_id: resource_type_id, numbering_level: 1}
      when resource_type_id == @container_resource_type_id ->
        # the target is a unit, so we sroll in the Y direction to it

        push_event(socket, "scroll-y-to-target", %{
          id: "unit_#{resource_id}",
          offset: 25,
          pulse: true,
          pulse_delay: 500
        })

      %{resource_type_id: resource_type_id, numbering_level: 2}
      when resource_type_id == @container_resource_type_id ->
        # the target is a module, so we scroll in the Y direction to the unit that is parent of that module,
        # and then scroll X in the slider to that module and expand it

        module_resource_id = String.to_integer(resource_id)

        unit_resource_id =
          Hierarchy.find_parent_in_hierarchy(
            full_hierarchy,
            fn node -> node["resource_id"] == module_resource_id end
          )["resource_id"]

        socket
        |> assign(
          selected_module_per_unit_resource_id:
            merge_target_module_as_selected(
              socket.assigns.selected_module_per_unit_resource_id,
              socket.assigns.section,
              socket.assigns.student_visited_pages,
              module_resource_id,
              unit_resource_id,
              full_hierarchy,
              socket.assigns.student_raw_avg_score_per_page_id,
              socket.assigns.student_progress_per_resource_id
            )
        )
        |> push_event("scroll-y-to-target", %{id: "unit_#{unit_resource_id}", offset: 25})
        |> push_event("scroll-x-to-card-in-slider", %{
          card_id: "module_#{resource_id}",
          scroll_delay: 300,
          unit_resource_id: unit_resource_id,
          pulse_target_id: "module_#{resource_id}",
          pulse_delay: 500
        })

      %{resource_type_id: resource_type_id, numbering_level: 1}
      when resource_type_id == @page_resource_type_id ->
        # the target is a page at the highest level (unit level), so we scroll in the Y direction to that page and pulse it

        push_event(socket, "scroll-y-to-target", %{
          id: "top_level_page_#{resource_id}",
          offset: 25,
          pulse: true,
          pulse_delay: 500
        })

      %{resource_type_id: resource_type_id, numbering_level: 2}
      when resource_type_id == @page_resource_type_id ->
        # the target is a page at a module level, so we scroll in the Y direction to the unit that is parent of that page,
        # and then scroll X in the slider to that page

        unit_resource_id =
          Hierarchy.find_parent_in_hierarchy(
            full_hierarchy,
            fn node -> node["resource_id"] == String.to_integer(resource_id) end
          )["resource_id"]

        socket
        |> push_event("scroll-y-to-target", %{id: "unit_#{unit_resource_id}", offset: 25})
        |> push_event("scroll-x-to-card-in-slider", %{
          card_id: "page_#{resource_id}",
          scroll_delay: 300,
          unit_resource_id: unit_resource_id,
          pulse_target_id: "page_#{resource_id}",
          pulse_delay: 500
        })

      %{resource_type_id: resource_type_id, numbering_level: level}
      when resource_type_id == @page_resource_type_id and level > 2 ->
        # the target is a page contained in a module or a section, so we scroll in the Y direction to the unit that is parent of that module,
        # and then scroll X in the slider to that module and expand it

        module_resource_id =
          Hierarchy.find_module_ancestor(
            full_hierarchy,
            String.to_integer(resource_id),
            @container_resource_type_id
          )["resource_id"]

        unit_resource_id =
          Hierarchy.find_parent_in_hierarchy(
            full_hierarchy,
            fn node ->
              node["resource_id"] == module_resource_id
            end
          )["resource_id"]

        socket
        |> assign(
          selected_module_per_unit_resource_id:
            merge_target_module_as_selected(
              socket.assigns.selected_module_per_unit_resource_id,
              socket.assigns.section,
              socket.assigns.student_visited_pages,
              module_resource_id,
              unit_resource_id,
              full_hierarchy,
              socket.assigns.student_raw_avg_score_per_page_id,
              socket.assigns.student_progress_per_resource_id
            )
        )
        |> push_event("scroll-y-to-target", %{id: "unit_#{unit_resource_id}", offset: 25})
        |> push_event("scroll-x-to-card-in-slider", %{
          card_id: "module_#{module_resource_id}",
          scroll_delay: 300,
          unit_resource_id: unit_resource_id,
          pulse_target_id: "index_item_#{resource_id}",
          pulse_delay: 500
        })

      _ ->
        socket
    end
  end

  def handle_event(
        "play_video",
        %{
          "video_url" => video_url,
          "module_resource_id" => resource_id,
          "section_id" => section_id,
          "is_intro_video" => is_intro_video
        },
        socket
      ) do
    resource_id = String.to_integer(resource_id)
    full_hierarchy = get_or_compute_full_hierarchy(socket.assigns.section)

    selected_unit =
      if String.to_existing_atom(is_intro_video) do
        Enum.find(full_hierarchy["children"], fn unit -> unit["resource_id"] == resource_id end)
      else
        Hierarchy.find_parent_in_hierarchy(
          full_hierarchy,
          fn node -> node["resource_id"] == resource_id end
        )
      end

    updated_viewed_videos =
      if resource_id in socket.assigns.viewed_intro_video_resource_ids do
        socket.assigns.viewed_intro_video_resource_ids
      else
        async_mark_video_as_viewed_in_student_enrollment_state(
          socket.assigns.current_user.id,
          socket.assigns.section.slug,
          resource_id
        )

        [resource_id | socket.assigns.viewed_intro_video_resource_ids]
      end

    send(self(), :gc)

    {:noreply,
     socket
     |> assign(viewed_intro_video_resource_ids: updated_viewed_videos)
     |> stream_insert(:units, selected_unit)
     |> push_event("play_video", %{
       "video_url" => video_url,
       "section_id" => section_id,
       "module_resource_id" => resource_id
     })}
  end

  def handle_event("change_selected_view", %{"selected_view" => selected_view}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         ~p"/sections/#{socket.assigns.section.slug}/learn?#{%{selected_view: selected_view, sidebar_expanded: socket.assigns.sidebar_expanded}}"
     )}
  end

  @doc """
  This event handler is responsible for toggling the module (expand or collapse it).
  Params:
    - `unit_resource_id` (required): the resource_id of the unit that contains the module.
    - `module_resource_id` (required): the resource_id of the module that should be toggled.
    - `force_auto_scroll?` (optional): a boolean that, in case of being true, it will force to autoscroll Y to the unit (defaults to false).
    - `scroll_behavior` (optional): the scroll behavior to be used when scrolling to the unit (defaults to "smooth").
    - `pulse_target_id` (optional): the id of the element that should be pulsed after the module is expanded (defaults to nil).
  """

  def handle_event(
        "toggle_module",
        %{"unit_resource_id" => unit_resource_id, "module_resource_id" => module_resource_id} =
          params,
        socket
      ) do
    force_auto_scroll? = params["force_auto_scroll?"] == "true"

    {:noreply,
     do_toggle_module(
       socket,
       unit_resource_id,
       module_resource_id,
       force_auto_scroll?,
       params["scroll_behavior"],
       params["pulse_target_id"]
     )}
  end

  def handle_event("navigate_to_resource", %{"slug" => _} = values, socket),
    do: navigate_to_resource(values, socket)

  def handle_event(
        "toggle_completed_pages",
        %{"module_resource_id" => module_resource_id},
        socket
      ) do
    full_hierarchy = get_or_compute_full_hierarchy(socket.assigns.section)
    module_resource_id = String.to_integer(module_resource_id)

    selected_unit =
      Hierarchy.find_parent_in_hierarchy(
        full_hierarchy,
        &(&1["resource_id"] == module_resource_id)
      )

    show_completed_pages? =
      not (socket.assigns.display_props_per_module_id
           |> get_in([module_resource_id, :show_completed_pages], true))

    display_props_per_module_id =
      Map.update(
        socket.assigns.display_props_per_module_id,
        module_resource_id,
        %{show_completed_pages: show_completed_pages?},
        fn _ -> %{show_completed_pages: show_completed_pages?} end
      )

    send(self(), :gc)

    {:noreply,
     socket
     |> assign(display_props_per_module_id: display_props_per_module_id)
     |> stream_insert(:units, selected_unit)}
  end

  ## Tab navigation start ##

  def handle_event("intro_card_keydown", params, socket) do
    case params["key"] do
      "Enter" ->
        {:noreply,
         push_event(socket, "play_video", %{
           "video_url" => params["video_url"],
           "module_resource_id" => params["card_resource_id"],
           "section_id" => params["section_id"]
         })}

      "Escape" ->
        {:noreply,
         push_event(socket, "js-exec", %{
           to: "#intro_card_#{params["card_resource_id"]}",
           attr: "data-event"
         })}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("card_keydown", %{"key" => "Escape"} = params, socket) do
    {:noreply,
     push_event(socket, "js-exec", %{
       to: "##{params["type"]}_#{params["module_resource_id"]}",
       attr: "data-leave-event"
     })}
  end

  def handle_event("card_keydown", %{"key" => "Enter"} = params, socket) do
    case params["type"] do
      "page" ->
        navigate_to_resource(params, socket)

      "module" ->
        {
          :noreply,
          do_toggle_module(socket, params["unit_resource_id"], params["module_resource_id"])
          |> push_event("js-exec", %{
            to: "##{params["type"]}_#{params["module_resource_id"]}",
            attr: "data-enter-event"
          })
        }

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("card_keydown", _, socket), do: {:noreply, socket}

  def enter_unit(js \\ %JS{}, unit_id) do
    unit_cards_selector = "#slider_focus_wrap_#{unit_id} > div[role*=\"card\"]"

    JS.set_attribute(js, {"tabindex", "0"}, to: unit_cards_selector)
    |> enable_focus_wrap_for("#slider_focus_wrap_#{unit_id}")
    |> JS.focus(to: unit_cards_selector <> ":first-of-type")
  end

  def leave_unit(js \\ %JS{}, unit_id) do
    JS.remove_attribute(js, "tabindex", to: "#slider_#{unit_id} > div[role*=\"card\"]")
    |> disable_focus_wrap_for("#slider_focus_wrap_#{unit_id}")
    |> JS.focus(to: "#unit_#{unit_id}")
  end

  def enter_module(js \\ %JS{}, unit_id) do
    module_items_selector = "#selected_module_in_unit_#{unit_id}"

    js
    |> enable_focus_wrap_for(module_items_selector)
    |> JS.focus_first(to: module_items_selector)
  end

  def leave_module(js \\ %JS{}, unit_id, module_resource_id) do
    module_items_selector = "#selected_module_in_unit_#{unit_id}"

    js
    |> disable_focus_wrap_for(module_items_selector)
    |> JS.set_attribute({"tabindex", "-1"}, to: "#{module_items_selector} button")
    |> JS.focus(to: "#module_#{module_resource_id}")
  end

  defp enable_focus_wrap_for(js, selector) do
    js
    |> JS.set_attribute({"tabindex", "0"}, to: "#{selector}-start")
    |> JS.set_attribute({"tabindex", "0"}, to: "#{selector}-end")
  end

  defp disable_focus_wrap_for(js, selector) do
    js
    |> JS.set_attribute({"tabindex", "-1"}, to: "#{selector}-start")
    |> JS.set_attribute({"tabindex", "-1"}, to: "#{selector}-end")
  end

  ## Tab navigation end ##

  defp do_toggle_module(
         socket,
         unit_resource_id,
         module_resource_id,
         force_auto_scroll? \\ false,
         scroll_behavior \\ "smooth",
         pulse_target_id \\ nil
       ) do
    unit_resource_id = String.to_integer(unit_resource_id)
    module_resource_id = String.to_integer(module_resource_id)
    full_hierarchy = get_or_compute_full_hierarchy(socket.assigns.section)

    selected_unit =
      Hierarchy.find_parent_in_hierarchy(
        full_hierarchy,
        fn node -> node["resource_id"] == module_resource_id end
      )

    current_selected_module_for_unit =
      Map.get(
        socket.assigns.selected_module_per_unit_resource_id,
        unit_resource_id
      )

    {selected_module_per_unit_resource_id, auto_scroll?} =
      case current_selected_module_for_unit do
        nil ->
          {Map.merge(socket.assigns.selected_module_per_unit_resource_id, %{
             unit_resource_id =>
               get_module(
                 full_hierarchy,
                 unit_resource_id,
                 module_resource_id
               )
               |> mark_visited_and_completed_pages(
                 socket.assigns.student_visited_pages,
                 socket.assigns.student_raw_avg_score_per_page_id,
                 socket.assigns.student_progress_per_resource_id
               )
             # The learning objectives tooltip was disabled in ticket NG-201 but will be reactivated with NG23-199
             #  |> fetch_learning_objectives(socket.assigns.section.id)
           }), true}

        current_module ->
          clicked_module =
            get_module(
              full_hierarchy,
              unit_resource_id,
              module_resource_id
            )

          if clicked_module["resource_id"] == current_module["resource_id"] do
            # if the user clicked in an already expanded module, then we should collapse it
            {Map.drop(
               socket.assigns.selected_module_per_unit_resource_id,
               [unit_resource_id]
             ), false}
          else
            {Map.merge(socket.assigns.selected_module_per_unit_resource_id, %{
               unit_resource_id =>
                 mark_visited_and_completed_pages(
                   clicked_module,
                   socket.assigns.student_visited_pages,
                   socket.assigns.student_raw_avg_score_per_page_id,
                   socket.assigns.student_progress_per_resource_id
                 )
               # The learning objectives tooltip was disabled in ticket NG-201 but will be reactivated with NG23-199
               #  |> fetch_learning_objectives(socket.assigns.section.id)
             }), true}
          end
      end

    # The default behaviour for a collapsed module is not to autoscroll to the unit,
    # except we explicitely required it (e.g. when collapsing the module through the "collapse module" botton)
    auto_scroll? = force_auto_scroll? || auto_scroll?

    send(self(), :gc)

    socket
    |> assign(selected_module_per_unit_resource_id: selected_module_per_unit_resource_id)
    |> stream_insert(:units, selected_unit)
    |> maybe_scroll_y_to_unit(unit_resource_id, auto_scroll?, scroll_behavior)
    |> maybe_scroll_x_to_card_in_slider(unit_resource_id, module_resource_id, auto_scroll?)
    |> maybe_pulse_target(pulse_target_id)
    |> push_event("hide-or-show-buttons-on-sliders", %{
      unit_resource_ids:
        Enum.map(
          full_hierarchy["children"],
          & &1["resource_id"]
        )
    })
    |> push_event("js-exec", %{
      to: "#selected_module_in_unit_#{unit_resource_id}",
      attr: "data-animate"
    })
  end

  def navigate_to_resource(values, socket) do
    section_slug = socket.assigns.section.slug
    resource_id = values["resource_id"] || values["module_resource_id"]
    selected_view = values["view"] || :gallery

    {:noreply,
     push_navigate(socket,
       to:
         resource_url(
           values["slug"],
           section_slug,
           resource_id,
           selected_view
         )
     )}
  end

  def toggle_module(js \\ %JS{}, unit_resource_id) do
    js
    |> JS.hide(
      to: "#selected_module_in_unit_#{unit_resource_id}",
      transition: {"ease-out duration-500", "opacity-100", "opacity-0"}
    )
    |> JS.push("toggle_module")
  end

  def collapse_module(js \\ %JS{}, unit_resource_id) do
    js
    |> JS.hide(
      to: "#selected_module_in_unit_#{unit_resource_id}",
      transition:
        {"ease-out duration-700", "opacity-100 scale-100 translate-y-0",
         "opacity-0 -translate-y-full"}
    )
    |> JS.push("toggle_module")
  end

  def handle_info(:gc, socket) do
    :erlang.garbage_collect(socket.transport_pid)
    :erlang.garbage_collect(self())
    {:noreply, socket}
  end

  def handle_info(
        {:student_metrics_and_enable_slider_buttons, nil},
        socket
      ) do
    send(self(), :gc)

    {:noreply, socket}
  end

  def handle_info(
        {:student_metrics_and_enable_slider_buttons,
         {student_visited_pages, student_progress_per_resource_id,
          student_raw_avg_score_per_page_id, student_raw_avg_score_per_container_id,
          student_end_date_exceptions_per_resource_id}},
        socket
      ) do
    %{
      section: section,
      selected_module_per_unit_resource_id: selected_module_per_unit_resource_id,
      selected_view: selected_view
    } = socket.assigns

    send(self(), :gc)

    units =
      get_or_compute_full_hierarchy(section)["children"]
      |> Enum.map(fn unit ->
        unit
        |> mark_visited_and_completed_pages(
          student_visited_pages,
          student_raw_avg_score_per_page_id,
          student_progress_per_resource_id
        )
      end)

    {:noreply,
     assign(socket,
       student_end_date_exceptions_per_resource_id: student_end_date_exceptions_per_resource_id,
       student_visited_pages: student_visited_pages,
       student_progress_per_resource_id: student_progress_per_resource_id,
       student_raw_avg_score_per_page_id: student_raw_avg_score_per_page_id,
       student_raw_avg_score_per_container_id: student_raw_avg_score_per_container_id,
       selected_module_per_unit_resource_id:
         Enum.into(
           selected_module_per_unit_resource_id,
           %{},
           fn {unit_resource_id, selected_module} ->
             {unit_resource_id,
              mark_visited_and_completed_pages(
                selected_module,
                student_visited_pages,
                student_raw_avg_score_per_page_id,
                student_progress_per_resource_id
              )}
           end
         )
     )
     |> stream(:units, units, reset: true)
     |> maybe_assign_gallery_data(selected_view, units)}
  end

  def handle_info(
        {:scroll_to_resource, resource_type, resource_id},
        socket
      ) do
    resource_type = if resource_type == "container", do: "unit", else: "top_level_page"

    {:noreply,
     push_event(socket, "scroll-y-to-target", %{
       id: "#{resource_type}_#{resource_id}",
       offset: 25,
       pulse: true,
       pulse_delay: 500
     })}
  end

  # needed to ignore results of Task invocation
  def handle_info(_, socket), do: {:noreply, socket}

  def render(%{selected_view: :outline} = assigns) do
    %{section: %{id: _section_id}} = assigns

    ~H"""
    <div id="student_learn" class="lg:container lg:mx-auto p-[25px]" phx-hook="Scroller">
      <.video_player />
      <div class="flex justify-end md:p-[25px]">
        <.live_component
          id="view_selector"
          module={OliWeb.Delivery.Student.Learn.Components.ViewSelector}
          selected_view={@selected_view}
        />
      </div>
      <div id="outline_rows" phx-update="stream">
        <.outline_row
          :for={{_, row} <- @streams.units}
          row={row}
          section={@section}
          type={child_type(row)}
          student_progress_per_resource_id={@student_progress_per_resource_id}
          viewed_intro_video_resource_ids={@viewed_intro_video_resource_ids}
          student_id={@current_user.id}
        />
      </div>
    </div>
    """
  end

  def render(%{selected_view: :gallery} = assigns) do
    ~H"""
    <div id="student_learn" class="lg:container lg:mx-auto p-[25px]" phx-hook="Scroller">
      <.video_player />
      <div class="flex justify-end md:p-[25px]">
        <.live_component
          id="view_selector"
          module={OliWeb.Delivery.Student.Learn.Components.ViewSelector}
          selected_view={@selected_view}
        />
      </div>
      <div id="all_units_as_gallery" phx-update="stream">
        <.gallery_row
          :for={{_, unit} <- @streams.units}
          unit={unit}
          ctx={@ctx}
          section={@section}
          student_progress_per_resource_id={@student_progress_per_resource_id}
          student_end_date_exceptions_per_resource_id={@student_end_date_exceptions_per_resource_id}
          selected_module_per_unit_resource_id={@selected_module_per_unit_resource_id}
          student_raw_avg_score_per_page_id={@student_raw_avg_score_per_page_id}
          page_metrics_per_module_id={@page_metrics_per_module_id}
          viewed_intro_video_resource_ids={@viewed_intro_video_resource_ids}
          progress={
            parse_student_progress_for_resource(
              @student_progress_per_resource_id,
              unit["resource_id"]
            )
          }
          student_id={@current_user.id}
          unit_raw_avg_score={
            Map.get(
              @student_raw_avg_score_per_container_id,
              unit["resource_id"],
              %{}
            )
          }
          assistant_enabled={@assistant_enabled}
          display_props_per_module_id={@display_props_per_module_id}
        />
      </div>
    </div>
    """
  end

  attr :unit, :map
  attr :section, :map
  attr :ctx, :map, doc: "the context is needed to format the date considering the user's timezone"
  attr :student_progress_per_resource_id, :map
  attr :student_raw_avg_score_per_page_id, :map
  attr :student_end_date_exceptions_per_resource_id, :map
  attr :selected_module_per_unit_resource_id, :map
  attr :progress, :integer
  attr :student_id, :integer
  attr :viewed_intro_video_resource_ids, :list
  attr :unit_raw_avg_score, :map
  attr :assistant_enabled, :boolean, required: true
  attr :display_props_per_module_id, :map
  attr :page_metrics_per_module_id, :map

  # top level page as a card with title and header
  def gallery_row(%{unit: %{"resource_type_id" => 1}} = assigns) do
    ~H"""
    <div id={"top_level_page_#{@unit["resource_id"]}"} tabindex="0">
      <div class="md:p-[25px] md:pl-[50px]" role={"top_level_page_#{@unit["numbering"]["index"]}"}>
        <div role="header" class="flex flex-col md:flex-row md:gap-[30px]">
          <div class="text-[14px] leading-[19px] tracking-[1.4px] uppercase mt-[7px] mb-1 whitespace-nowrap opacity-60">
            <%= "PAGE #{@unit["numbering"]["index"]}" %>
          </div>
          <div class="mb-6 flex flex-col items-start gap-[6px] w-full">
            <div class="flex w-full">
              <h3 class="text-[26px] leading-[32px] tracking-[0.02px] font-normal dark:text-[#DDD]">
                <%= @unit["title"] %>
              </h3>
              <div class="ml-auto flex items-center gap-3" role="schedule_details">
                <div class="text-[14px] leading-[32px] tracking-[0.02px] font-semibold">
                  <span class="text-gray-400 opacity-80 dark:text-[#696974] dark:opacity-100 mr-1">
                    <%= Utils.label_for_scheduling_type(@unit["section_resource"].scheduling_type) %>
                  </span>
                  <%= format_date(
                    @unit["section_resource"].end_date,
                    @ctx,
                    "{WDshort}, {Mshort} {D}, {YYYY} ({h12}:{m}{am})"
                  ) %>
                </div>
              </div>
            </div>
            <div class="flex items-center gap-6">
              <.progress_bar
                percent={@progress}
                width="194px"
                on_going_colour="bg-[#0CAF61]"
                completed_colour="bg-[#0CAF61]"
                role={"unit_#{@unit["numbering"]["index"]}_progress"}
              />
            </div>
          </div>
        </div>
        <div class="flex">
          <.card
            card={@unit}
            module_index={1}
            unit_resource_id={@unit["resource_id"]}
            unit_numbering_index={@unit["numbering"]["index"]}
            bg_image_url={@unit["poster_image"]}
            student_progress_per_resource_id={@student_progress_per_resource_id}
            selected={
              @selected_module_per_unit_resource_id[@unit["resource_id"]]["resource_id"] ==
                @unit["resource_id"]
            }
          />
        </div>
      </div>
    </div>
    """
  end

  def gallery_row(assigns) do
    ~H"""
    <div
      id={"unit_#{@unit["resource_id"]}"}
      tabindex="0"
      phx-keydown={enter_unit(@unit["resource_id"])}
      phx-key="enter"
    >
      <div class="md:p-[25px] md:pl-[50px]" role={"unit_#{@unit["numbering"]["index"]}"}>
        <div class="flex flex-col md:flex-row md:gap-[30px]">
          <div class="text-[14px] leading-[19px] tracking-[1.4px] uppercase mt-[7px] mb-1 whitespace-nowrap opacity-60">
            <%= container_label_and_numbering(
              @unit["numbering"]["level"],
              @unit["numbering"]["index"],
              @section.customizations
            ) %>
          </div>
          <div class="mb-6 flex flex-col items-start gap-[6px] w-full">
            <div class="flex w-full">
              <h3 class="text-[26px] leading-[32px] tracking-[0.02px] font-normal dark:text-[#DDD]">
                <%= @unit["title"] %>
              </h3>
              <div class="ml-auto flex items-center gap-3" role="schedule_details">
                <div class="text-[14px] leading-[32px] tracking-[0.02px] font-semibold">
                  <span class="text-gray-400 opacity-80 dark:text-[#696974] dark:opacity-100 mr-1">
                    Due:
                  </span>
                  <%= format_date(
                    @unit["section_resource"].end_date,
                    @ctx,
                    "{WDshort}, {Mshort} {D}, {YYYY} ({h12}:{m}{am})"
                  ) %>
                </div>
              </div>
            </div>
            <div class="flex items-center gap-6">
              <.progress_bar
                percent={@progress}
                width="194px"
                on_going_colour="bg-[#0CAF61]"
                completed_colour="bg-[#0CAF61]"
                role={"unit_#{@unit["numbering"]["index"]}_progress"}
              />
            </div>
          </div>
        </div>
        <div class="flex relative">
          <button
            id={"slider_left_button_#{@unit["resource_id"]}"}
            class="hidden absolute items-center justify-start -top-1 -left-1 w-10 bg-gradient-to-r from-gray-100 dark:from-[#0D0C0F] h-[187px] z-20 text-gray-700 dark:text-gray-600 hover:text-xl hover:dark:text-gray-200 hover:w-16 cursor-pointer"
            tabindex="-1"
          >
            <i class="fa-solid fa-chevron-left ml-3"></i>
          </button>
          <button
            id={"slider_right_button_#{@unit["resource_id"]}"}
            class="hidden absolute items-center justify-end -top-1 -right-1 w-10 bg-gradient-to-l from-gray-100 dark:from-[#0D0C0F] h-[187px] z-20 text-gray-700 dark:text-gray-600 hover:text-xl hover:dark:text-gray-200 hover:w-16 cursor-pointer"
            tabindex="-1"
          >
            <i class="fa-solid fa-chevron-right mr-3"></i>
          </button>
          <div
            id={"slider_#{@unit["resource_id"]}"}
            role="slider"
            phx-hook="SliderScroll"
            data-resource_id={@unit["resource_id"]}
            class="overflow-y-hidden h-[187px] pt-[5px] px-[5px] scrollbar-hide"
          >
            <.custom_focus_wrap
              id={"slider_focus_wrap_#{@unit["resource_id"]}"}
              initially_enabled={false}
              class="flex"
            >
              <.intro_video_card
                :if={@unit["intro_video"]}
                section={@section}
                video_url={@unit["intro_video"]}
                duration_minutes={@unit["duration_minutes"]}
                card_resource_id={@unit["resource_id"]}
                intro_video_viewed={@unit["resource_id"] in @viewed_intro_video_resource_ids}
                is_youtube_video={WebUtils.is_youtube_video?(@unit["intro_video"])}
              />
              <.card
                :for={module <- @unit["children"]}
                card={module}
                module_index={module["numbering"]["index"]}
                section_customizations={@section.customizations}
                unit_resource_id={@unit["resource_id"]}
                unit_numbering_index={@unit["numbering"]["index"]}
                bg_image_url={module["poster_image"]}
                student_progress_per_resource_id={@student_progress_per_resource_id}
                selected={
                  @selected_module_per_unit_resource_id[@unit["resource_id"]]["resource_id"] ==
                    module["resource_id"]
                }
                page_metrics={
                  get_module_page_metrics(@page_metrics_per_module_id, module["resource_id"])
                }
              />
            </.custom_focus_wrap>
          </div>
        </div>
      </div>
      <div class="overflow-hidden">
        <.custom_focus_wrap
          :if={Map.has_key?(@selected_module_per_unit_resource_id, @unit["resource_id"])}
          class="px-[50px] rounded-lg flex-col justify-start items-center gap-[25px] flex"
          role="module_details"
          id={"selected_module_in_unit_#{@unit["resource_id"]}"}
          data-animate={
            JS.show(
              to: "#selected_module_in_unit_#{@unit["resource_id"]}",
              display: "flex",
              transition: {"ease-out duration-1000", "opacity-0", "opacity-100"}
            )
          }
          phx-window-keydown={
            leave_module(
              @unit["resource_id"],
              @selected_module_per_unit_resource_id[@unit["resource_id"]]["resource_id"]
            )
            |> JS.dispatch("click",
              to:
                "#module_#{@selected_module_per_unit_resource_id[@unit["resource_id"]]["resource_id"]}"
            )
          }
          phx-key="Escape"
        >
          <div
            role="expanded module header"
            class="self-stretch px-6 py-0.5 flex-col justify-start items-center gap-2 flex"
          >
            <div class="justify-start items-start gap-1 inline-flex">
              <div class="opacity-60 dark:text-white text-sm font-bold font-['Open Sans'] uppercase tracking-tight">
                <%= container_label_and_numbering(
                  Map.get(@selected_module_per_unit_resource_id, @unit["resource_id"])["numbering"][
                    "level"
                  ],
                  Map.get(@selected_module_per_unit_resource_id, @unit["resource_id"])["numbering"][
                    "index"
                  ],
                  @section.customizations
                ) %>
              </div>
            </div>
            <h2 class="self-stretch opacity-90 text-center text-[26px] font-normal font-['Open Sans'] leading-loose tracking-tight dark:text-white">
              <%= Map.get(@selected_module_per_unit_resource_id, @unit["resource_id"])[
                "title"
              ] %>
            </h2>
            <span class="opacity-50 dark:text-white text-xs font-normal font-['Open Sans']">
              Due: <%= format_date(
                Map.get(@selected_module_per_unit_resource_id, @unit["resource_id"])[
                  "section_resource"
                ].end_date,
                @ctx,
                "{WDshort} {Mshort} {D}, {YYYY}"
              ) %>
            </span>
          </div>
          <div
            :if={
              Map.get(@selected_module_per_unit_resource_id, @unit["resource_id"])[
                "intro_content"
              ][
                "children"
              ]
            }
            id={"module_intro_contentin_unit_#{@unit["resource_id"]}"}
            role="module intro content"
            class="max-w-[760px] w-full pt-[25px] pb-2.5 justify-start items-start gap-[23px] inline-flex"
          >
            <div class="flex flex-col opacity-80">
              <span
                data-toggle_read_more_button_id={"toggle_read_more_#{Map.get(@selected_module_per_unit_resource_id, @unit["resource_id"])["resource_id"]}"}
                phx-hook="ToggleReadMore"
                id={"selected_module_in_unit_#{@unit["resource_id"]}_intro_content"}
                class="text-sm font-normal font-['Open Sans'] leading-[30px] max-w-[760px] overflow-hidden dark:text-white"
                style="display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical;"
              >
                <%= render_intro_content(
                  Map.get(@selected_module_per_unit_resource_id, @unit["resource_id"])[
                    "intro_content"
                  ][
                    "children"
                  ]
                ) %>
              </span>
              <div
                id={"toggle_read_more_#{Map.get(@selected_module_per_unit_resource_id, @unit["resource_id"])["resource_id"]}"}
                class="ml-auto"
              >
                <button
                  id={"read_more_module_intro_in_unit_#{@unit["resource_id"]}"}
                  phx-click={
                    JS.remove_attribute("style",
                      to: "#selected_module_in_unit_#{@unit["resource_id"]}_intro_content"
                    )
                    |> JS.toggle(to: "#read_less_module_intro_in_unit_#{@unit["resource_id"]}")
                    |> JS.toggle()
                  }
                  class="text-blue-500 text-sm font-normal font-['Open Sans'] leading-[30px] ml-auto"
                >
                  Read more
                </button>
                <button
                  id={"read_less_module_intro_in_unit_#{@unit["resource_id"]}"}
                  phx-click={
                    JS.set_attribute(
                      {"style",
                       "display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical;"},
                      to: "#selected_module_in_unit_#{@unit["resource_id"]}_intro_content"
                    )
                    |> JS.toggle(to: "#read_more_module_intro_in_unit_#{@unit["resource_id"]}")
                    |> JS.toggle()
                  }
                  class="hidden text-blue-500 text-sm font-normal font-['Open Sans'] leading-[30px] ml-auto"
                >
                  Read less
                </button>
              </div>
            </div>
          </div>
          <button
            :if={@assistant_enabled}
            phx-click={JS.dispatch("click", to: "#ai_bot_collapsed_button")}
            class="h-[39px] p-2.5 bg-blue-500 hover:bg-blue-600 focus:bg-blue-600 dark:bg-blue-700 dark:hover:bg-opacity-60 dark:focus:bg-opacity-60 rounded text-white text-sm font-semibold font-['Open Sans'] tracking-tight"
          >
            Let's discuss?
          </button>

          <div
            role="module index"
            class="flex flex-col max-w-[760px] pt-[25px] pb-2.5 justify-start items-start gap-[23px] w-full"
          >
            <div class="w-full">
              <% module =
                Map.get(@selected_module_per_unit_resource_id, @unit["resource_id"]) %>
              <.module_content_header
                module={module}
                page_metrics={
                  get_module_page_metrics(@page_metrics_per_module_id, module["resource_id"])
                }
                show_completed_pages={
                  get_in(
                    @display_props_per_module_id,
                    [module["resource_id"], :show_completed_pages],
                    true
                  )
                }
              />
              <.module_index
                module={module}
                section={@section}
                student_raw_avg_score_per_page_id={@student_raw_avg_score_per_page_id}
                student_progress_per_resource_id={@student_progress_per_resource_id}
                student_end_date_exceptions_per_resource_id={
                  @student_end_date_exceptions_per_resource_id
                }
                ctx={@ctx}
                student_id={@student_id}
                intro_video_viewed={
                  Map.get(@selected_module_per_unit_resource_id, @unit["resource_id"])["resource_id"] in @viewed_intro_video_resource_ids
                }
                display_props_per_module_id={@display_props_per_module_id}
              />
            </div>
          </div>
          <div role="collapse_bar" class="w-full px-2.5 justify-center items-center inline-flex">
            <div class="grow shrink basis-0 h-px bg-white/20"></div>
            <button
              phx-click={collapse_module(@unit["resource_id"])}
              phx-value-unit_resource_id={@unit["resource_id"]}
              phx-value-module_resource_id={module["resource_id"]}
              phx-value-force_auto_scroll?="true"
              phx-value-scroll_behavior="auto"
              phx-value-pulse_target_id={"module_#{module["resource_id"]}"}
              role="collapse module button"
              class="pl-5 pr-4 rounded-[82px] border border-white/20 dark:text-white opacity-80 hover:opacity-100 hoverjustify-center items-center gap-3 flex"
            >
              <div class="text-[13px] font-semibold font-['Open Sans'] leading-loose tracking-tight">
                Collapse Module
              </div>
              <Icons.chevron_down class="w-4 h-4 opacity-90 rotate-180" />
            </button>
            <div class="grow shrink basis-0 h-px bg-white/20"></div>
          </div>
        </.custom_focus_wrap>
      </div>
    </div>
    """
  end

  def outline_row(%{type: :unit} = assigns) do
    ~H"""
    <div id={"unit_#{@row["resource_id"]}"}>
      <div class="md:p-[25px] md:pl-[125px] md:pr-[175px]" role={"row_#{@row["numbering"]["index"]}"}>
        <div class="flex flex-col md:flex-row md:gap-[30px]">
          <div class="dark:text-white text-xl font-bold font-['Open Sans']">
            <%= "#{Sections.get_container_label_and_numbering(1, @row["numbering"]["index"], @section.customizations)}: #{@row["title"]}" %>
          </div>
        </div>
        <div class="flex flex-col mt-6">
          <.outline_row
            :for={row <- @row["children"]}
            section={@section}
            row={row}
            type={child_type(row)}
            student_progress_per_resource_id={@student_progress_per_resource_id}
            viewed_intro_video_resource_ids={@viewed_intro_video_resource_ids}
            student_id={@student_id}
          />
        </div>
      </div>
    </div>
    """
  end

  def outline_row(%{type: :top_level_page} = assigns) do
    ~H"""
    <div id={"top_level_page_#{@row["resource_id"]}"}>
      <div class="md:p-[25px] md:pl-[125px] md:pr-[175px]" role={"row_#{@row["numbering"]["index"]}"}>
        <div role="header" class="flex flex-col md:flex-row md:gap-[30px]">
          <div class="dark:text-white text-xl font-bold font-['Open Sans']">
            <%= @row["title"] %>
          </div>
        </div>
        <div class="flex flex-col mt-6">
          <.outline_row
            section={@section}
            row={@row}
            type={:page}
            student_progress_per_resource_id={@student_progress_per_resource_id}
            viewed_intro_video_resource_ids={@viewed_intro_video_resource_ids}
            student_id={@student_id}
          />
        </div>
      </div>
    </div>
    """
  end

  def outline_row(%{type: type} = assigns) when type in [:module, :section] do
    ~H"""
    <div id={"#{@type}_#{@row["resource_id"]}"}>
      <div class="w-full pl-[5px] pr-[7px] py-2.5 rounded-lg justify-start items-center gap-5 flex">
        <div class="justify-start items-start gap-5 flex">
          <.no_icon />
          <div class="w-[26px] justify-start items-center">
            <div class="grow shrink basis-0 opacity-60 dark:text-white text-[13px] font-semibold font-['Open Sans'] capitalize">
              <.numbering_index type={Atom.to_string(@type)} />
            </div>
          </div>
        </div>
        <div class={[
          "dark:text-white text-base font-bold font-['Open Sans']",
          left_indentation(@row["numbering"]["level"], :outline)
        ]}>
          <span><%= @row["title"] %></span>
          <div
            :if={@type == :module and @row["intro_content"]["children"] not in ["", nil]}
            class="mt-3 dark:text-white text-base font-normal font-['Open Sans']"
          >
            <%= render_intro_content(@row["intro_content"]["children"]) %>
          </div>
        </div>
      </div>
      <div class="flex flex-col">
        <.intro_video_item
          :if={@type == :module and module_has_intro_video(@row)}
          duration_minutes={@row["duration_minutes"]}
          section={@section}
          module_resource_id={@row["resource_id"]}
          video_url={@row["intro_video"]}
          intro_video_viewed={@row["resource_id"] in @viewed_intro_video_resource_ids}
          view={:outline}
        />
        <.outline_row
          :for={row <- @row["children"]}
          section={@section}
          row={row}
          type={child_type(row)}
          student_progress_per_resource_id={@student_progress_per_resource_id}
          viewed_intro_video_resource_ids={@viewed_intro_video_resource_ids}
          student_id={@student_id}
        />
      </div>
    </div>
    """
  end

  def outline_row(%{type: :page} = assigns) do
    ~H"""
    <div id={"page_#{@row["resource_id"]}"}>
      <button
        role={"page #{@row["numbering"]["index"]} details"}
        class={[
          "w-full pl-[5px] pr-[7px] py-2.5 justify-start items-center gap-5 flex rounded-lg focus:bg-[#000000]/5 hover:bg-[#000000]/5 dark:focus:bg-[#FFFFFF]/5 dark:hover:bg-[#FFFFFF]/5",
          if(@row["graded"],
            do: "font-semibold hover:font-bold focus:font-bold",
            else: "font-normal hover:font-medium focus:font-medium"
          )
        ]}
        id={"index_item_#{@row["id"]}"}
        phx-click="navigate_to_resource"
        phx-value-view={:outline}
        phx-value-slug={@row["slug"]}
        phx-value-resource_id={@row["resource_id"]}
      >
        <div class="justify-start items-start gap-5 flex">
          <.index_item_icon
            item_type={Atom.to_string(@type)}
            was_visited={@row["visited"]}
            graded={@row["graded"]}
            raw_avg_score={@row["score"]}
            progress={@row["progress"]}
          />
          <div class="w-[26px] justify-start items-center">
            <div class="grow shrink basis-0 opacity-60 dark:text-white text-[13px] font-semibold font-['Open Sans'] capitalize">
              <.numbering_index type={Atom.to_string(@type)} index={@row["numbering"]["index"]} />
            </div>
          </div>
        </div>

        <div
          id={"index_item_#{@row["numbering"]["index"]}_#{@row["resource_id"]}"}
          class="flex shrink items-center gap-3 w-full dark:text-white"
        >
          <div class={[
            "flex flex-col gap-1 w-full",
            left_indentation(@row["numbering"]["level"], :outline)
          ]}>
            <div class="flex">
              <span
                role="page title"
                class={
                  [
                    "text-left dark:text-white opacity-90 text-base font-['Open Sans']",
                    # Opacity is set if the item is visited, but not necessarily completed
                    if(@row["visited"], do: "opacity-60")
                  ]
                }
              >
                <%= "#{@row["title"]}" %>
              </span>

              <Student.duration_in_minutes
                duration_minutes={@row["duration_minutes"]}
                graded={@row["graded"]}
              />
            </div>
          </div>
        </div>
      </button>
    </div>
    """
  end

  attr :module, :map
  attr :show_completed_pages, :boolean, default: true
  attr :page_metrics, :map, default: @default_module_page_metrics

  def module_content_header(assigns) do
    ~H"""
    <div class="w-full border-b dark:border-white/20 flex items-center justify-between pb-1.5">
      <div role="completed count" class="flex gap-2.5">
        <div class="w-7 h-8 py-1 flex gap-2.5">
          <Icons.check />
        </div>
        <div class="w-34 h-8 pl-1 flex gap-1.5">
          <div class="flex gap-0.5 items-center">
            <span class="opacity-80 dark:text-white text-[13px] font-normal font-['Open Sans'] leading-loose">
              <%= case @page_metrics do
                %{total_pages_count: 1, completed_pages_count: 1} ->
                  "1 of 1 Page"

                %{total_pages_count: total_count, completed_pages_count: completed_count} ->
                  "#{completed_count} of #{total_count} Pages"
              end %>
            </span>
          </div>
        </div>
      </div>
      <button
        role="toggle completed button"
        class="flex items-center opacity-80 hover:opacity-100 cursor-pointer pr-2"
        phx-click="toggle_completed_pages"
        phx-value-module_resource_id={@module["resource_id"]}
      >
        <div class="w-8 h-8 flex justify-center items-center">
          <Icons.visible :if={!@show_completed_pages} />
          <Icons.hidden :if={@show_completed_pages} />
        </div>

        <div class="flex gap-1.5">
          <div class="flex gap-0.5 items-center">
            <span class="opacity-80 dark:text-white text-[13px] font-semibold font-['Open Sans'] leading-loose tracking-tight">
              <%= if @show_completed_pages, do: "Hide", else: "Show" %> Completed
            </span>
          </div>
        </div>
      </button>
    </div>
    <div class="pt-6" />
    """
  end

  attr :section, :any
  attr :module, :map
  attr :student_raw_avg_score_per_page_id, :map
  attr :student_end_date_exceptions_per_resource_id, :map
  attr :ctx, :map, required: true
  attr :student_id, :integer
  attr :intro_video_viewed, :boolean
  attr :student_progress_per_resource_id, :map
  attr :display_props_per_module_id, :map

  def module_index(assigns) do
    show_completed_pages =
      get_in(
        assigns.display_props_per_module_id,
        [assigns.module["resource_id"], :show_completed_pages],
        true
      )

    assigns =
      Map.merge(assigns, %{
        show_completed_pages: show_completed_pages,
        page_due_dates:
          get_contained_pages_due_dates(
            assigns.module,
            assigns.student_end_date_exceptions_per_resource_id,
            show_completed_pages,
            assigns.ctx
          )
      })

    ~H"""
    <div
      id={"index_for_#{@module["resource_id"]}"}
      class="relative flex flex-col gap-[25px] items-start"
    >
      <%!-- This learning objectives tooltip was hidden in ticket NG-201 but will be reactivated with NG23-199 --%>

      <%!-- <div
        :if={@module["learning_objectives"] != []}
        phx-click-away={JS.hide(to: "#learning_objectives_#{@module["resource_id"]}")}
        class="hidden flex-col gap-3 w-full p-6 bg-white dark:bg-[#242533] shadow-xl rounded-xl absolute top-[35px] left-0 z-50"
        id={"learning_objectives_#{@module["resource_id"]}"}
        role="learning objectives tooltip"
      >
        <Icons.right_arrow class="absolute -top-[8px] left-[8px] w-[27px] h-3 fill-white dark:fill-[#242533] -rotate-90" />
        <div class="flex items-center gap-[10px] mb-3">
          <h3 class="text-[12px] leading-[16px] tracking-[0.96px] dark:opacity-40 font-bold uppercase dark:text-white">
            Learning Objectives
          </h3>
          <button
            phx-click={JS.hide(to: "#learning_objectives_#{@module["resource_id"]}")}
            tabindex="0"
            class="ml-auto cursor-pointer hover:opacity-50 hover:scale-105"
          >
            <Icons.close class="stroke-black dark:stroke-white" />
          </button>
        </div>
        <ul class="flex flex-col gap-[6px]">
          <li
            :for={{learning_objective, index} <- Enum.with_index(@module["learning_objectives"], 1)}
            class="flex py-1"
          >
            <span class="w-[30px] text-[12px] leading-[24px] font-bold dark:text-white dark:opacity-40">
              <%= "L#{index}" %>
            </span>
            <span class="text-[14px] leading-[24px] tracking-[0.02px] dark:text-white dark:opacity-80">
              <%= learning_objective.title %>
            </span>
          </li>
        </ul>
      </div>
      <button
        :if={@module["learning_objectives"] != []}
        role="module learning objectives"
        class="hidden items-center gap-[14px] px-[10px] w-full p-1 cursor-pointer"
        phx-click={JS.toggle(to: "#learning_objectives_#{@module["resource_id"]}", display: "flex")}
      >
        <Icons.learning_objectives class="fill-black dark:fill-white" />
        <h3 class="text-[16px] leading-[22px] font-semibold dark:text-white">
          Introduction and Learning Objectives
        </h3>
      </button> --%>
      <.intro_video_item
        :if={module_has_intro_video(@module)}
        section={@section}
        duration_minutes={@module["duration_minutes"]}
        module_resource_id={@module["resource_id"]}
        video_url={@module["intro_video"]}
        intro_video_viewed={@intro_video_viewed}
      />
      <div
        :for={{grouped_scheduling_type, grouped_due_date} <- @page_due_dates}
        class="flex flex-col w-full"
        id={"pages_grouped_by_#{grouped_scheduling_type}_#{grouped_due_date}"}
      >
        <div class="h-[19px] mb-5">
          <span class="dark:text-white text-sm font-bold font-['Open Sans']">
            <%= "#{Utils.label_for_scheduling_type(grouped_scheduling_type)}#{format_date(grouped_due_date, @ctx, "{WDshort} {Mshort} {D}, {YYYY}")}" %>
          </span>
        </div>
        <.index_item
          :for={child <- @module["children"]}
          :if={
            display_module_item?(
              @show_completed_pages,
              grouped_due_date,
              grouped_scheduling_type,
              @student_end_date_exceptions_per_resource_id,
              child,
              @ctx
            )
          }
          title={child["title"]}
          type={
            if is_section?(child),
              do: "section",
              else: "page"
          }
          numbering_index={child["numbering"]["index"]}
          numbering_level={child["numbering"]["level"]}
          children={child["children"]}
          was_visited={child["visited"]}
          duration_minutes={child["duration_minutes"]}
          graded={child["graded"]}
          revision_slug={child["slug"]}
          module_resource_id={@module["resource_id"]}
          resource_id={child["resource_id"]}
          student_id={@student_id}
          ctx={@ctx}
          student_end_date_exceptions_per_resource_id={@student_end_date_exceptions_per_resource_id}
          parent_due_date={grouped_due_date}
          parent_scheduling_type={grouped_scheduling_type}
          due_date={
            get_due_date_for_student(
              child["section_resource"].end_date,
              child["resource_id"],
              @student_end_date_exceptions_per_resource_id
            )
          }
          student_raw_avg_score_per_page_id={@student_raw_avg_score_per_page_id}
          raw_avg_score={Map.get(@student_raw_avg_score_per_page_id, child["resource_id"])}
          progress={Map.get(@student_progress_per_resource_id, child["resource_id"])}
          student_progress_per_resource_id={@student_progress_per_resource_id}
          show_completed_pages={@show_completed_pages}
        />
      </div>
    </div>
    """
  end

  attr :title, :string
  attr :type, :string
  attr :numbering_index, :integer
  attr :numbering_level, :integer
  attr :children, :list, default: []
  attr :was_visited, :boolean
  attr :duration_minutes, :integer
  attr :revision_slug, :string
  attr :module_resource_id, :integer
  attr :resource_id, :string
  attr :student_id, :integer
  attr :ctx, :map, required: true
  attr :graded, :boolean
  attr :raw_avg_score, :map
  attr :student_raw_avg_score_per_page_id, :map
  attr :student_end_date_exceptions_per_resource_id, :map
  attr :student_progress_per_resource_id, :map
  attr :due_date, Date
  attr :parent_due_date, Date
  attr :parent_scheduling_type, :atom
  attr :progress, :float
  attr :show_completed_pages, :boolean

  def index_item(%{type: "section"} = assigns) do
    assigns =
      Map.put(assigns, :section_attrs, %{
        "numbering" => %{"level" => assigns.numbering_level},
        "children" => assigns.children,
        "resource_type_id" => Oli.Resources.ResourceType.get_id_by_type("container")
      })

    ~H"""
    <div
      :if={
        display_module_item?(
          @show_completed_pages,
          @parent_due_date,
          @parent_scheduling_type,
          @student_end_date_exceptions_per_resource_id,
          @section_attrs,
          @ctx
        )
      }
      role={"#{@type} #{@numbering_index} details"}
      class="w-full pl-[5px] pr-[7px] py-2.5 justify-start items-center gap-5 flex rounded-lg"
      id={"index_item_#{@resource_id}_#{@parent_scheduling_type}_#{@parent_due_date}"}
      phx-value-resource_id={@resource_id}
      phx-value-parent_due_date={@parent_due_date}
      phx-value-module_resource_id={@module_resource_id}
    >
      <div class="justify-start items-start gap-5 flex">
        <.no_icon />
        <div class="w-[26px] justify-start items-center">
          <div class="grow shrink basis-0 opacity-60 text-white text-[13px] font-semibold font-['Open Sans'] capitalize">
            <.numbering_index type={@type} index={@numbering_index} />
          </div>
        </div>
      </div>

      <div class="flex shrink items-center gap-3 w-full dark:text-white">
        <div class="flex flex-col gap-1 w-full">
          <div class={["flex", left_indentation(@numbering_level)]}>
            <span class="opacity-90 dark:text-white text-base font-semibold font-['Open Sans']">
              <%= "#{@title}" %>
            </span>
          </div>
        </div>
      </div>
    </div>
    <div
      id={"section_group_#{@resource_id}_#{@parent_due_date}"}
      class="flex relative flex-col items-center w-full"
    >
      <.index_item
        :for={child <- @children}
        :if={
          display_module_item?(
            @show_completed_pages,
            @parent_due_date,
            @parent_scheduling_type,
            @student_end_date_exceptions_per_resource_id,
            child,
            @ctx
          )
        }
        title={child["title"]}
        type={
          if is_section?(child),
            do: "section",
            else: "page"
        }
        numbering_index={child["numbering"]["index"]}
        numbering_level={child["numbering"]["level"]}
        children={child["children"]}
        was_visited={child["visited"]}
        duration_minutes={child["duration_minutes"]}
        graded={child["graded"]}
        revision_slug={child["slug"]}
        module_resource_id={@module_resource_id}
        resource_id={child["resource_id"]}
        student_id={@student_id}
        ctx={@ctx}
        student_end_date_exceptions_per_resource_id={@student_end_date_exceptions_per_resource_id}
        parent_due_date={@parent_due_date}
        parent_scheduling_type={@parent_scheduling_type}
        due_date={
          get_due_date_for_student(
            child["section_resource"].end_date,
            child["resource_id"],
            @student_end_date_exceptions_per_resource_id
          )
        }
        raw_avg_score={Map.get(@student_raw_avg_score_per_page_id, child["resource_id"])}
        student_raw_avg_score_per_page_id={@student_raw_avg_score_per_page_id}
        progress={Map.get(@student_progress_per_resource_id, child["resource_id"])}
        student_progress_per_resource_id={@student_progress_per_resource_id}
        show_completed_pages={@show_completed_pages}
      />
    </div>
    """
  end

  def index_item(assigns) do
    ~H"""
    <button
      role={"#{@type} #{@numbering_index} details"}
      class={[
        "w-full pl-[5px] pr-[7px] py-2.5 rounded-lg justify-start items-center gap-5 flex focus:bg-[#000000]/5 hover:bg-[#000000]/5 dark:focus:bg-[#FFFFFF]/5 dark:hover:bg-[#FFFFFF]/5",
        if(@graded,
          do: "font-semibold hover:font-bold focus:font-bold",
          else: "font-normal hover:font-medium focus:font-medium"
        )
      ]}
      id={"index_item_#{@resource_id}"}
      phx-click="navigate_to_resource"
      phx-value-slug={@revision_slug}
      phx-value-resource_id={@resource_id}
      phx-value-module_resource_id={@module_resource_id}
    >
      <div class="justify-start items-start gap-5 flex">
        <.index_item_icon
          item_type={@type}
          was_visited={@was_visited}
          graded={@graded}
          raw_avg_score={@raw_avg_score[:score]}
          progress={@progress}
        />
        <div class="w-[26px] justify-start items-center">
          <div class="grow shrink basis-0 opacity-60 text-white text-[13px] font-semibold font-['Open Sans'] capitalize">
            <.numbering_index type={@type} index={@numbering_index} />
          </div>
        </div>
      </div>

      <div
        id={"index_item_#{@numbering_index}_#{@resource_id}"}
        class="flex shrink items-center gap-3 w-full dark:text-white"
      >
        <div class={["flex flex-col gap-1 w-full", left_indentation(@numbering_level)]}>
          <div class="flex">
            <span class={
              [
                "text-left dark:text-white opacity-90 text-base font-['Open Sans']",
                # Opacity is set if the item is visited, but not necessarily completed
                if(@was_visited, do: "opacity-60")
              ]
            }>
              <%= "#{@title}" %>
            </span>

            <Student.duration_in_minutes duration_minutes={@duration_minutes} graded={@graded} />
          </div>
          <div :if={@graded} role="due date and score" class="flex">
            <span class="opacity-60 text-[13px] font-normal font-['Open Sans'] !font-normal opacity-60 dark:text-white">
              <%= Utils.label_for_scheduling_type(@parent_scheduling_type) %><%= format_date(
                @due_date,
                @ctx,
                "{WDshort} {Mshort} {D}, {YYYY}"
              ) %>
            </span>
            <Student.score_summary raw_avg_score={@raw_avg_score} />
          </div>
        </div>
      </div>
    </button>
    """
  end

  attr :section, :any
  attr :duration_minutes, :integer
  attr :module_resource_id, :integer
  attr :intro_video_viewed, :boolean
  attr :video_url, :string, default: nil
  attr :view, :atom, default: @default_selected_view

  def intro_video_item(assigns) do
    ~H"""
    <button
      role="intro video details"
      class="w-full pl-[5px] pr-[7px] py-2.5 justify-start items-center gap-5 flex rounded-lg focus:bg-[#000000]/5 hover:bg-[#000000]/5 dark:focus:bg-[#FFFFFF]/5 dark:hover:bg-[#FFFFFF]/5 font-normal hover:font-medium focus:font-medium"
      id={"intro_video_for_module_#{@module_resource_id}"}
      phx-click="play_video"
      phx-value-section_id={@section.id}
      phx-value-module_resource_id={@module_resource_id}
      phx-value-video_url={@video_url}
      phx-value-is_intro_video="false"
    >
      <div
        role={"#{if @intro_video_viewed, do: "seen", else: "unseen"} video icon"}
        class="flex justify-center items-center h-7 w-7 shrink-0"
      >
        <Icons.video
          class="fill-black dark:fill-white"
          path_class={
            if(@intro_video_viewed,
              do: "!opacity-100 fill-[#0CAF61] dark:fill-[#12E56A]",
              else: "opacity-60"
            )
          }
        />
      </div>
      <div class="flex shrink items-center gap-3 w-full dark:text-white">
        <div class={[
          "flex flex-col gap-1 w-full",
          if(@view == :outline, do: "ml-[60px]", else: "ml-10")
        ]}>
          <div class="flex">
            <span class={
              [
                "text-left dark:text-white opacity-90 text-base font-['Open Sans']",
                # Opacity is set if the intro video is viewed, but not necessarily completed
                if(@intro_video_viewed, do: "opacity-60")
              ]
            }>
              Introduction
            </span>

            <Student.duration_in_minutes duration_minutes={@duration_minutes} />
          </div>
        </div>
      </div>
    </button>
    """
  end

  attr :item_type, :string
  attr :was_visited, :boolean
  attr :graded, :boolean
  attr :raw_avg_score, :map
  attr :progress, :float

  def index_item_icon(assigns) do
    case {assigns.was_visited || false, assigns.item_type, assigns.graded, assigns.raw_avg_score} do
      {_, "page", false, _} ->
        # visited practice page (check icon shown when progress = 100%)
        ~H"""
        <Icons.check progress={@progress} />
        """

      {true, "page", true, raw_avg_score} when not is_nil(raw_avg_score) ->
        # completed graded page
        ~H"""
        <div role="square check icon" class="flex justify-center items-center w-[22px] h-[22px] shrink-0">
          <Icons.square_checked />
        </div>
        """

      {_, "page", true, _} ->
        # not completed graded page
        ~H"""
        <div role="orange flag icon" class="flex justify-center items-center w-[22px] h-[22px] shrink-0">
          <Icons.flag />
        </div>
        """
    end
  end

  attr :section, :any
  attr :title, :string, default: "INTRO"
  attr :video_url, :string
  attr :card_resource_id, :string
  attr :intro_video_viewed, :boolean, default: false
  attr :is_youtube_video, :boolean, default: false
  attr :duration_minutes, :integer

  def intro_video_card(%{is_youtube_video: true} = assigns) do
    ~H"""
    <div
      id={"intro_card_#{@card_resource_id}"}
      class="relative slider-card mr-4 rounded-xl hover:outline hover:outline-[3px] outline-gray-800 dark:outline-white"
      role="youtube_intro_video_card"
      phx-keydown="intro_card_keydown"
      phx-value-video_url={@video_url}
      phx-value-card_resource_id={@card_resource_id}
      phx-value-section_id={@section.id}
      data-event={leave_unit(@card_resource_id)}
      phx-click="play_video"
      phx-value-section_id={@section.id}
      phx-value-video_url={@video_url}
      phx-value-module_resource_id={@card_resource_id}
      phx-value-is_intro_video="true"
    >
      <div
        xphx-mouseover={JS.show(to: "#card_badge_details_#{@card_resource_id}")}
        xphx-mouseout={JS.hide(to: "#card_badge_details_#{@card_resource_id}")}
        class="rounded-xl absolute overflow-hidden h-[170px] w-[294px] cursor-pointer bg-[linear-gradient(180deg,#223_0%,rgba(34,34,51,0.72)_52.6%,rgba(34,34,51,0.00)_100%)]"
      >
        <div class="mt-[166px]">
          <.progress_bar
            percent={if @intro_video_viewed, do: 100, else: 0}
            width="100%"
            height="h-[4px]"
            show_percent={false}
            on_going_colour="bg-[#0CAF61]"
            completed_colour="bg-[#0CAF61]"
            role="intro video card progress"
          />
        </div>
      </div>
      <div
        class="flex flex-col items-center rounded-xl h-[170px] w-[294px] bg-gray-200/50 shrink-0 px-5 pt-[15px] bg-cover bg-center"
        style={"background-image: url('#{WebUtils.convert_to_youtube_image_url(@video_url)}');"}
      >
        <span
          role="card top label"
          class="pointer-events-none text-[12px] leading-[16px] font-bold opacity-60 text-white dark:text-opacity-50 self-start"
        >
          <%= @title %>
        </span>
        <div class="absolute bottom-4 right-3 h-[26px] pointer-events-none">
          <.card_badge
            resource_id={@card_resource_id}
            duration_minutes={@duration_minutes}
            completed={@intro_video_viewed}
          />
        </div>
        <div
          id={"intro_video_card_#{@card_resource_id}"}
          class="w-[70px] h-[70px] relative my-auto -top-2 cursor-pointer pointer-events-none"
        >
          <div class="w-full h-full rounded-full backdrop-blur bg-gray/50"></div>
          <div
            role="play_unit_intro_video"
            class="w-full h-full absolute top-0 left-0 flex items-center justify-center"
          >
            <Icons.play class="scale-110 ml-[6px] mt-[9px]" />
          </div>
        </div>
      </div>
    </div>
    """
  end

  def intro_video_card(%{is_youtube_video: false} = assigns) do
    ~H"""
    <div
      id={"intro_card_#{@card_resource_id}"}
      class="relative slider-card mr-4 rounded-xl hover:outline hover:outline-[3px] outline-gray-800 dark:outline-white"
      role="intro_video_card"
      phx-keydown="intro_card_keydown"
      phx-value-video_url={@video_url}
      phx-value-section_id={@section.id}
      phx-value-card_resource_id={@card_resource_id}
      data-event={leave_unit(@card_resource_id)}
      phx-click="play_video"
      phx-value-section_id={@section.id}
      phx-value-video_url={@video_url}
      phx-value-module_resource_id={@card_resource_id}
      phx-value-is_intro_video="true"
    >
      <div
        xphx-mouseover={JS.show(to: "#card_badge_details_#{@card_resource_id}")}
        xphx-mouseout={JS.hide(to: "#card_badge_details_#{@card_resource_id}")}
        class="rounded-xl absolute overflow-hidden h-[170px] w-[294px] cursor-pointer bg-[linear-gradient(180deg,#223_0%,rgba(34,34,51,0.72)_52.6%,rgba(34,34,51,0.00)_100%)]"
      >
        <div class="mt-[166px]">
          <.progress_bar
            percent={if @intro_video_viewed, do: 100, else: 0}
            width="100%"
            height="h-[4px]"
            show_percent={false}
            on_going_colour="bg-[#0CAF61]"
            completed_colour="bg-[#0CAF61]"
            role="intro video card progress"
          />
        </div>
      </div>
      <div class="flex flex-col items-center rounded-xl h-[170px] w-[294px] bg-gray-200/50 shrink-0 px-5 pt-[15px] bg-cover bg-center">
        <video
          id={"video_preview_image_#{@video_url}"}
          class="rounded-xl object-cover absolute h-[170px] w-[294px] top-0 pointer-events-none"
          preload="metadata"
        >
          <source src={"#{@video_url}#t=0.5"} /> Your browser does not support the video tag.
        </video>
        <span
          role="card top label"
          class="pointer-events-none text-[12px] leading-[16px] font-bold opacity-60 text-white dark:text-opacity-50 self-start"
        >
          <%= @title %>
        </span>
        <div class="absolute bottom-4 right-3 h-[26px] pointer-events-none">
          <.card_badge
            resource_id={@card_resource_id}
            duration_minutes={@duration_minutes}
            completed={@intro_video_viewed}
          />
        </div>
        <div
          id={"intro_video_card_#{@card_resource_id}"}
          class="w-[70px] h-[70px] relative my-auto -top-2 cursor-pointer pointer-events-none"
        >
          <div class="w-full h-full rounded-full backdrop-blur bg-gray/50"></div>
          <div
            role="play_unit_intro_video"
            class="w-full h-full absolute top-0 left-0 flex items-center justify-center"
          >
            <Icons.play class="scale-110 ml-[6px] mt-[9px]" />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :card, :map
  attr :module_index, :integer
  attr :unit_numbering_index, :integer
  attr :section_customizations, :map
  attr :unit_resource_id, :string
  attr :selected, :boolean, default: false
  attr :bg_image_url, :string, doc: "the background image url for the card"
  attr :student_progress_per_resource_id, :map
  attr :default_image, :string, default: @default_image
  attr :page_metrics, :map, default: @default_module_page_metrics

  def card(assigns) do
    assigns = Map.put(assigns, :is_page, is_page(assigns.card))

    ~H"""
    <div
      id={
        if @is_page,
          do: "page_#{@card["resource_id"]}",
          else: "module_#{@card["resource_id"]}"
      }
      phx-click={
        if @is_page,
          do: "navigate_to_resource",
          else: toggle_module(@unit_resource_id)
      }
      phx-keydown="card_keydown"
      phx-value-unit_resource_id={@unit_resource_id}
      phx-value-module_resource_id={@card["resource_id"]}
      phx-value-slug={@card["slug"]}
      phx-value-type={if @is_page, do: "page", else: "module"}
      class={[
        "relative slider-card mr-4 rounded-xl hover:outline hover:outline-[3px] outline-gray-800 dark:outline-white",
        if(@selected, do: "outline outline-[3px]")
      ]}
      role={"card_#{@module_index}"}
      data-enter-event={enter_module(@unit_resource_id)}
      data-leave-event={leave_unit(@unit_resource_id)}
      aria-expanded={Kernel.to_string(@selected)}
    >
      <div
        xphx-mouseover={JS.show(to: "#card_badge_details_#{@card["resource_id"]}")}
        xphx-mouseout={JS.hide(to: "#card_badge_details_#{@card["resource_id"]}")}
        class="rounded-xl absolute h-[170px] w-[294px] overflow-hidden cursor-pointer bg-[linear-gradient(180deg,#223_0%,rgba(34,34,51,0.72)_52.6%,rgba(34,34,51,0.00)_100%)]"
      >
        <div class="mt-[166px]" role={"card #{@module_index} progress"}>
          <.progress_bar
            percent={
              parse_student_progress_for_resource(
                @student_progress_per_resource_id,
                @card["resource_id"]
              )
            }
            width="100%"
            height="h-[4px]"
            show_percent={false}
            on_going_colour="bg-[#0CAF61]"
            completed_colour="bg-[#0CAF61]"
            role={"card_#{@module_index}_progress"}
          />
        </div>
      </div>

      <div class="h-[170px] w-[294px]">
        <div
          class={[
            "flex flex-col gap-[5px] cursor-pointer rounded-xl h-[170px] w-[294px] shrink-0 mb-1 px-5 pt-[15px] bg-gray-200 z-10 bg-cover bg-center"
          ]}
          style={"background-image: url('#{if(@bg_image_url in ["", nil], do: @default_image, else: @bg_image_url)}');"}
        >
          <span
            role="card top label"
            class="pointer-events-none text-[12px] leading-[16px] font-bold opacity-60 text-white dark:text-opacity-50"
          >
            <%= if @is_page,
              do: "PAGE",
              else:
                container_label_and_numbering(
                  @card["numbering"]["level"],
                  @module_index,
                  @section_customizations
                ) %>
          </span>
          <h5 class="pointer-events-none text-[18px] leading-[25px] font-bold text-white z-10">
            <%= @card["title"] %>
          </h5>
          <div class="absolute bottom-4 right-3 h-[26px] pointer-events-none">
            <.module_card_badge
              :if={!@is_page}
              page_metrics={@page_metrics}
              resource_id={@card["resource_id"]}
            />
            <.card_badge
              :if={@is_page}
              resource_id={@card["resource_id"]}
              duration_minutes={@card["duration_minutes"]}
              completed={@card["completed"]}
            />
          </div>
        </div>
        <div
          :if={@selected}
          class={[
            "flex justify-center items-center -mt-1"
          ]}
        >
          <Icons.down_arrow />
        </div>
      </div>
    </div>
    """
  end

  attr :resource_id, :string
  attr :duration_minutes, :integer
  attr :completed, :boolean

  def card_badge(%{completed: true} = assigns) do
    ~H"""
    <% parsed_minutes = parse_card_badge_minutes(@duration_minutes, :page) %>

    <div
      role="card badge"
      class="h-[26px] px-2 py-1 dark:bg-white/10 rounded-xl shadow justify-end items-center gap-1 inline-flex overflow-hidden"
    >
      <Icons.check />
      <div
        :if={parsed_minutes}
        id={"card_badge_details_#{@resource_id}"}
        class="hidden dark:text-white text-[13px] font-semibold pointer-events-none"
      >
        <%= parsed_minutes %>
      </div>
    </div>
    """
  end

  def card_badge(assigns) do
    ~H"""
    <% parsed_minutes = parse_card_badge_minutes(@duration_minutes, :page) %>

    <div
      :if={parsed_minutes}
      role="card badge"
      class="h-[26px] px-2 py-1 dark:bg-white/10 rounded-xl shadow justify-end items-center gap-1 inline-flex overflow-hidden"
    >
      <div class="dark:text-white text-[13px] font-semibold pointer-events-none">
        <%= parsed_minutes %>
      </div>
    </div>
    """
  end

  attr :page_metrics, :map
  attr :resource_id, :string

  def module_card_badge(
        %{
          page_metrics: %{
            completed_pages_count: completed_pages_count,
            total_pages_count: total_pages_count
          }
        } =
          assigns
      )
      when completed_pages_count < total_pages_count do
    ~H"""
    <% parsed_minutes = parse_card_badge_minutes(@page_metrics.total_duration_minutes, :module) %>
    <div
      role="card badge"
      id={"in_progress_card_badge_#{@resource_id}"}
      class="ml-auto h-[26px] px-2 py-1 dark:bg-white/10 rounded-xl shadow justify-end items-center gap-1 inline-flex"
    >
      <div class="dark:text-white text-[13px] font-semibold">
        <%= parse_module_total_pages(@page_metrics.total_pages_count) <>
          if parsed_minutes, do: " · #{parsed_minutes}" %>
      </div>
    </div>
    """
  end

  def module_card_badge(
        %{
          page_metrics: %{
            completed_pages_count: completed_pages_count,
            total_pages_count: total_pages_count
          }
        } =
          assigns
      )
      when completed_pages_count == total_pages_count do
    ~H"""
    <% parsed_minutes = parse_card_badge_minutes(@page_metrics.total_duration_minutes, :module) %>

    <div
      role="card badge"
      class="h-[26px] px-2 py-1 dark:bg-white/10 rounded-xl shadow justify-end items-center gap-1 inline-flex overflow-hidden"
    >
      <Icons.check />
      <div
        id={"card_badge_details_#{@resource_id}"}
        class="hidden dark:text-white text-[13px] font-semibold pointer-events-none"
      >
        <%= parse_module_total_pages(@page_metrics.total_pages_count) <>
          if parsed_minutes, do: " · #{parsed_minutes}" %>
      </div>
    </div>
    """
  end

  def video_player(assigns) do
    ~H"""
    <div id="student_video_wrapper" phx-hook="VideoPlayer" class="hidden">
      <iframe id="youtube_video" frameborder="0" allowfullscreen></iframe>
      <video id="cloud_video" controls>
        <source src="" type="video/mp4" /> Your browser does not support the video tag.
      </video>
    </div>
    """
  end

  attr :type, :string
  attr :index, :string

  defp numbering_index(assigns) do
    ~H"""
    <span class="opacity-60 text-black dark:text-white text-[13px] font-semibold font-['Open Sans'] capitalize">
      <%= if @type == "page", do: "#{@index}", else: " " %>
    </span>
    """
  end

  defp no_icon(assigns) do
    ~H"""
    <div role="no icon" class="flex justify-center items-center w-[22px] h-[22px] shrink-0"></div>
    """
  end

  defp render_intro_content(intro_content) do
    Phoenix.HTML.raw(
      Oli.Rendering.Content.render(
        %Oli.Rendering.Context{},
        intro_content,
        Oli.Rendering.Content.Html
      )
    )
  end

  defp get_module(hierarchy, unit_resource_id, module_resource_id) do
    unit =
      Enum.find(hierarchy["children"], fn unit ->
        unit["resource_id"] == unit_resource_id
      end)

    Enum.find(unit["children"], fn module ->
      module["resource_id"] == module_resource_id
    end)
  end

  defp resource_url(resource_slug, section_slug, resource_id, selected_view) do
    Utils.lesson_live_path(
      section_slug,
      resource_slug,
      request_path:
        Utils.learn_live_path(section_slug,
          target_resource_id: resource_id,
          selected_view: selected_view
        ),
      selected_view: selected_view
    )
  end

  defp get_student_metrics(section, current_user_id) do
    student_end_date_exceptions_per_resource_id =
      Oli.Delivery.Settings.get_student_exception_setting_for_all_resources(
        section.id,
        current_user_id,
        [:end_date]
      )
      |> Enum.reduce(%{}, fn {resource_id, settings}, acc ->
        Map.put(acc, resource_id, settings[:end_date])
      end)

    visited_pages_map = Sections.get_visited_pages(section.id, current_user_id)

    %{"container" => container_ids, "page" => page_ids} =
      Sections.get_resource_ids_group_by_resource_type(section.slug)

    progress_per_container_id =
      Metrics.progress_across(section.id, container_ids, current_user_id)
      |> Enum.into(%{}, fn {container_id, progress} ->
        {container_id, progress || 0.0}
      end)

    progress_per_page_id =
      Metrics.progress_across_for_pages(section.id, page_ids, [current_user_id])

    raw_avg_score_per_page_id =
      Metrics.raw_avg_score_across_for_pages(section, page_ids, [current_user_id])

    raw_avg_score_per_container_id =
      Metrics.raw_avg_score_across_for_containers(section, container_ids, [current_user_id])

    progress_per_resource_id =
      Map.merge(progress_per_page_id, progress_per_container_id)
      |> Map.filter(fn {_, progress} -> progress not in [nil, 0.0] end)

    {visited_pages_map, progress_per_resource_id, raw_avg_score_per_page_id,
     raw_avg_score_per_container_id, student_end_date_exceptions_per_resource_id}
  end

  defp mark_visited_and_completed_pages(
         %{"resource_type_id" => resource_type_id} = top_level_page_resource,
         visited_pages,
         student_raw_avg_score_per_page_id,
         student_progress_per_resource_id
       )
       when resource_type_id == @page_resource_type_id do
    score =
      get_in(student_raw_avg_score_per_page_id, [top_level_page_resource["resource_id"], :score])

    progress = student_progress_per_resource_id[top_level_page_resource["resource_id"]]
    visited? = Map.get(visited_pages, top_level_page_resource["id"], false)
    completed? = completed_page?(top_level_page_resource["graded"], visited?, score, progress)

    top_level_page_resource
    |> Map.put("visited", Map.get(visited_pages, top_level_page_resource["id"], false))
    |> Map.put("completed", completed?)
    |> Map.put("progress", progress)
    |> Map.put("score", score)
  end

  defp mark_visited_and_completed_pages(
         %{"resource_type_id" => resource_type_id} = container,
         visited_pages,
         student_raw_avg_score_per_page_id,
         student_progress_per_resource_id
       )
       when resource_type_id == @container_resource_type_id do
    update_in(
      container,
      ["children"],
      &Enum.map(&1, fn resource ->
        mark_visited_and_completed_pages(
          resource,
          visited_pages,
          student_raw_avg_score_per_page_id,
          student_progress_per_resource_id
        )
      end)
    )
  end

  defp completed_page?(true = _graded, visited?, raw_avg_score, progress),
    do: visited? and not is_nil(raw_avg_score) and progress == 1.0

  defp completed_page?(false = _graded, visited?, _score, progress),
    do: visited? and progress == 1.0

  defp module_page_metrics(container) do
    Enum.reduce(
      container["children"],
      @default_module_page_metrics,
      fn
        %{"resource_type_id" => @page_resource_type_id} = page,
        %{
          total_pages_count: total_pages_count,
          completed_pages_count: completed_pages_count,
          total_duration_minutes: total_duration_minutes
        } ->
          %{
            total_pages_count: total_pages_count + 1,
            completed_pages_count: completed_pages_count + if(page["completed"], do: 1, else: 0),
            total_duration_minutes: total_duration_minutes + (page["duration_minutes"] || 0)
          }

        %{"resource_type_id" => @container_resource_type_id} = section,
        %{
          total_pages_count: total_pages_count,
          completed_pages_count: completed_pages_count,
          total_duration_minutes: total_duration_minutes
        } ->
          %{
            total_pages_count: total,
            completed_pages_count: completed,
            total_duration_minutes: minutes
          } =
            module_page_metrics(section)

          %{
            total_pages_count: total_pages_count + total,
            completed_pages_count: completed_pages_count + completed,
            total_duration_minutes: total_duration_minutes + minutes
          }
      end
    )
  end

  defp page_metrics_per_module_id(resources, pages_per_module_id \\ %{})

  defp page_metrics_per_module_id([], pages_per_module_id), do: pages_per_module_id

  defp page_metrics_per_module_id(
         [
           %{"numbering" => %{"level" => level}, "resource_type_id" => resource_type_id} =
             resource
           | rest
         ],
         pages_per_module_id
       ) do
    resource_completed_and_total_pages =
      case {level, resource_type_id} do
        {1, @container_resource_type_id} ->
          # unit
          Map.merge(
            pages_per_module_id,
            page_metrics_per_module_id(resource["children"], pages_per_module_id)
          )

        {2, @container_resource_type_id} ->
          # module
          page_metrics_per_module_id(
            rest,
            Map.merge(pages_per_module_id, %{
              resource["resource_id"] => module_page_metrics(resource)
            })
          )

        _ ->
          pages_per_module_id
      end

    page_metrics_per_module_id(rest, resource_completed_and_total_pages)
  end

  defp display_module_item?(
         _show_completed_pages,
         _grouped_due_date,
         _grouped_scheduling_type,
         _student_end_date_exceptions_per_resource_id,
         %{"section_resource" => %{scheduling_type: :inclass_activity}} = _child,
         _ctx
       ),
       do: false

  defp display_module_item?(
         _show_completed_pages,
         _grouped_due_date,
         "Not yet scheduled" = _grouped_scheduling_type,
         _student_end_date_exceptions_per_resource_id,
         %{"section_resource" => %{end_date: end_date}} = _child,
         _ctx
       )
       when end_date in [nil, ""],
       do: true

  defp display_module_item?(
         show_completed_pages,
         grouped_due_date,
         grouped_scheduling_type,
         student_end_date_exceptions_per_resource_id,
         child,
         ctx
       ) do
    if is_section?(child) do
      Enum.any?(
        child["children"],
        &display_module_item?(
          show_completed_pages,
          grouped_due_date,
          grouped_scheduling_type,
          student_end_date_exceptions_per_resource_id,
          &1,
          ctx
        )
      )
    else
      # this due date considers the student exception (if any)
      student_due_date =
        Map.get(
          student_end_date_exceptions_per_resource_id,
          child["resource_id"],
          child["section_resource"].end_date
        )
        |> then(&if is_nil(&1), do: "Not yet scheduled", else: to_localized_date(&1, ctx))

      if show_completed_pages do
        student_due_date == grouped_due_date and
          grouped_scheduling_type == child["section_resource"].scheduling_type
      else
        !child["completed"] and student_due_date == grouped_due_date and
          grouped_scheduling_type == child["section_resource"].scheduling_type
      end
    end
  end

  # In-class Activities should not appear in the course content in the learn page (but only in the schedule) so we can ignore those.
  # As for 'read by' (lessons) and 'due date' (graded assignments) we assumed that we could group both together and treat the Read By Date as a general Due Date
  defp get_contained_pages_due_dates(
         container,
         student_end_date_exceptions_per_resource_id,
         show_completed_pages,
         ctx
       ) do
    contained_pages_due_dates(
      container,
      student_end_date_exceptions_per_resource_id,
      show_completed_pages,
      ctx
    )
    |> Enum.uniq()
    |> then(fn scheduling_type_date_keywords ->
      has_a_not_scheduled_resource =
        Enum.any?(scheduling_type_date_keywords, fn {_scheduling_type, date} ->
          is_nil(date)
        end)

      if has_a_not_scheduled_resource do
        # this guarantees not scheduled pages are grouped at the bootom of the list
        scheduling_type_date_keywords
        |> Enum.reject(fn {_st, date} -> is_nil(date) end)
        |> Enum.sort_by(fn {_st, date} -> date end, {:asc, Date})
        |> Enum.concat([{"Not yet scheduled", "Not yet scheduled"}])
      else
        Enum.sort_by(scheduling_type_date_keywords, fn {_st, date} -> date end, {:asc, Date})
      end
    end)
  end

  defp contained_pages_due_dates(
         container,
         student_end_date_exceptions_per_resource_id,
         show_completed_pages,
         ctx
       ) do
    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_type_id = Oli.Resources.ResourceType.get_id_by_type("container")

    Enum.flat_map(container["children"], fn
      %{
        "resource_type_id" => ^page_type_id,
        "completed" => completed,
        "section_resource" => %{
          scheduling_type: scheduling_type,
          end_date: end_date,
          resource_id: resource_id
        }
      }
      when scheduling_type in [:due_by, :read_by] ->
        if completed and !show_completed_pages do
          []
        else
          [
            {scheduling_type,
             Map.get(student_end_date_exceptions_per_resource_id, resource_id, end_date) &&
               to_localized_date(
                 Map.get(
                   student_end_date_exceptions_per_resource_id,
                   resource_id,
                   end_date
                 ),
                 ctx
               )}
          ]
        end

      %{"resource_type_id" => ^container_type_id} = section_or_subsection ->
        contained_pages_due_dates(
          section_or_subsection,
          student_end_date_exceptions_per_resource_id,
          show_completed_pages,
          ctx
        )

      _ ->
        []
    end)
  end

  defp to_localized_date(datetime, ctx) do
    datetime
    |> DateTime.shift_zone!(ctx.local_tz)
    |> DateTime.to_date()
  end

  defp parse_student_progress_for_resource(student_progress_per_resource_id, resource_id) do
    Map.get(student_progress_per_resource_id, resource_id, 0.0)
    |> Kernel.*(100)
    |> format_float()
  end

  defp format_float(float) do
    float
    |> round()
    |> trunc()
  end

  defp async_calculate_student_metrics_and_enable_slider_buttons(
         liveview_pid,
         section,
         %User{id: current_user_id}
       ) do
    Task.Supervisor.start_child(Oli.TaskSupervisor, fn ->
      send(
        liveview_pid,
        {:student_metrics_and_enable_slider_buttons,
         get_student_metrics(section, current_user_id)}
      )
    end)
  end

  defp async_calculate_student_metrics_and_enable_slider_buttons(
         liveview_pid,
         _section,
         _current_user
       ) do
    Task.Supervisor.start_child(Oli.TaskSupervisor, fn ->
      send(
        liveview_pid,
        {:student_metrics_and_enable_slider_buttons, nil}
      )
    end)
  end

  defp is_page(%{"resource_type_id" => resource_type_id}),
    do: resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page")

  _docp = """
    When a user collapses a module card, we do not want to autoscroll in the Y
    direction to focus on the unit that contains that card.
  """

  defp maybe_scroll_y_to_unit(socket, _unit_resource_id, false, _scroll_behavior), do: socket

  defp maybe_scroll_y_to_unit(socket, unit_resource_id, true, scroll_behavior) do
    push_event(socket, "scroll-y-to-target", %{
      id: "unit_#{unit_resource_id}",
      offset: 25,
      scroll_behavior: scroll_behavior
    })
  end

  _docp = """
    When a user expands a module card we want to autoscroll in the X direction to get
    that card (if possible) centered in the slider.
    When a user collapses a module card, we do not want to autoscroll in the X.
  """

  def maybe_scroll_x_to_card_in_slider(socket, _unit_resource_id, _module_resource_id, false),
    do: socket

  def maybe_scroll_x_to_card_in_slider(socket, unit_resource_id, module_resource_id, true) do
    push_event(socket, "scroll-x-to-card-in-slider", %{
      card_id: "module_#{module_resource_id}",
      unit_resource_id: unit_resource_id
    })
  end

  def maybe_pulse_target(socket, nil) do
    socket
  end

  def maybe_pulse_target(socket, target_id) do
    push_event(socket, "pulse-target", %{
      target_id: target_id
    })
  end

  _docp = """
  When rendering learn page in gallery view, we need to calculate the unit and module metrics
  """

  defp maybe_assign_gallery_data(socket, :gallery, units_with_metrics) do
    socket
    |> assign(page_metrics_per_module_id: page_metrics_per_module_id(units_with_metrics))
    |> enable_gallery_slider_buttons(units_with_metrics)
  end

  defp maybe_assign_gallery_data(socket, _another_view, _units_with_metrics), do: socket

  _docp = """
  When rendering learn page in gallery view, we need to execute the Scroller hook to enable the slider buttons
  """

  defp enable_gallery_slider_buttons(socket, units) do
    push_event(socket, "enable-slider-buttons", %{
      unit_resource_ids:
        Enum.map(
          units,
          & &1["resource_id"]
        )
    })
  end

  defp module_has_intro_video(module), do: module["intro_video"] != nil

  _docp = """
  This function returns the end date for a resource considering the student exception (if any)
  """

  defp get_due_date_for_student(
         end_date,
         resource_id,
         student_end_date_exceptions_per_resource_id
       ) do
    Map.get(student_end_date_exceptions_per_resource_id, resource_id, end_date)
  end

  defp format_date("Not yet scheduled", _context, _format), do: "Not yet scheduled"

  defp format_date(due_date, context, format) do
    FormatDateTime.to_formatted_datetime(due_date, context, format)
  end

  defp get_viewed_intro_video_resource_ids(section_slug, current_user_id) do
    Sections.get_enrollment(section_slug, current_user_id).state[
      "viewed_intro_video_resource_ids"
    ] ||
      []
  end

  defp async_mark_video_as_viewed_in_student_enrollment_state(
         student_id,
         section_slug,
         resource_id
       ) do
    Task.Supervisor.start_child(Oli.TaskSupervisor, fn ->
      student_enrollment =
        Sections.get_enrollment(section_slug, student_id)

      updated_state =
        case student_enrollment.state["viewed_intro_video_resource_ids"] do
          nil ->
            Map.merge(student_enrollment.state, %{
              "viewed_intro_video_resource_ids" => [resource_id]
            })

          viewed_intro_video_resource_ids ->
            Map.merge(student_enrollment.state, %{
              "viewed_intro_video_resource_ids" => [
                resource_id | viewed_intro_video_resource_ids
              ]
            })
        end

      Sections.update_enrollment(student_enrollment, %{state: updated_state})
    end)
  end

  # The learning objectives tooltip was disabled in ticket NG-201 but will be reactivated with NG23-199

  # defp fetch_learning_objectives(module, section_id) do
  #   Map.merge(module, %{
  #     "learning_objectives" =>
  #       Sections.get_learning_objectives_for_container_id(
  #         section_id,
  #         module["resource_id"]
  #       )
  #   })
  # end

  defp merge_target_module_as_selected(
         selected_module_per_unit_resource_id,
         _section,
         student_visited_pages,
         module_resource_id,
         unit_resource_id,
         full_hierarchy,
         student_raw_avg_score_per_page_id,
         student_progress_per_resource_id
       ) do
    Map.merge(
      selected_module_per_unit_resource_id,
      %{
        unit_resource_id =>
          get_module(
            full_hierarchy,
            unit_resource_id,
            module_resource_id
          )
          |> mark_visited_and_completed_pages(
            student_visited_pages,
            student_raw_avg_score_per_page_id,
            student_progress_per_resource_id
          )
        # The learning objectives tooltip was disabled in ticket NG-201 but will be reactivated with NG23-199
        # |> fetch_learning_objectives(section.id)
      }
    )
  end

  def get_or_compute_full_hierarchy(section) do
    SectionCache.get_or_compute(section.slug, :full_hierarchy, fn ->
      Hierarchy.full_hierarchy(section)
    end)
  end

  defp is_section?(child),
    do:
      Oli.Resources.ResourceType.get_type_by_id(child["resource_type_id"]) == "container" and
        child["numbering"]["level"] > 2

  defp child_type(child) do
    case {Oli.Resources.ResourceType.get_type_by_id(child["resource_type_id"]),
          child["numbering"]["level"]} do
      {"container", 1} -> :unit
      {"container", 2} -> :module
      {"container", _} -> :section
      {"page", 1} -> :top_level_page
      {"page", _} -> :page
    end
  end

  defp left_indentation(numbering_level, view \\ :gallery)

  defp left_indentation(numbering_level, view) do
    level_adjustment = if view == :outline, do: 1, else: 0

    case numbering_level + level_adjustment do
      4 -> "ml-[20px]"
      5 -> "ml-[40px]"
      6 -> "ml-[60px]"
      7 -> "ml-[80px]"
      level when level >= 8 -> "ml-[100px]"
      _ -> "ml-0"
    end
  end

  defp get_module_page_metrics(page_metrics_per_module_id, module_resource_id) do
    page_metrics_per_module_id[module_resource_id] || @default_module_page_metrics
  end

  defp parse_module_total_pages(pages) when is_integer(pages) do
    pages
    |> case do
      1 -> "1 page"
      _ -> "#{pages} pages"
    end
  end

  defp parse_module_total_pages(_), do: "unknown pages"

  defp parse_card_badge_minutes(minutes, resource_type) when is_integer(minutes) do
    clock_duration =
      minutes
      |> Timex.Duration.from_minutes()
      |> Timex.Duration.to_clock()

    case {clock_duration, resource_type} do
      {{hours, minutes, _seconds, _milliseconds}, :module} when hours > 0 ->
        "#{hours}h #{minutes}m"

      {{_, minutes, _seconds, _milliseconds}, :module} ->
        "#{minutes}m"

      {{hours, minutes, _seconds, _milliseconds}, :page} when hours > 0 ->
        "#{hours}h #{minutes}m"

      {{_, minutes, _seconds, _milliseconds}, :page} ->
        "#{minutes} min"
    end
  end

  defp parse_card_badge_minutes(_, _), do: nil

  defp container_label_and_numbering(numbering_level, numbering, customizations) do
    Sections.get_container_label_and_numbering(numbering_level, numbering, customizations)
    |> String.upcase()
  end

  defp get_selected_view(params) do
    case params["selected_view"] do
      nil -> nil
      view when view not in ~w(gallery outline) -> @default_selected_view
      view -> String.to_existing_atom(view)
    end
  end

  defp maybe_assign_selected_view(socket, nil), do: socket
  defp maybe_assign_selected_view(socket, view), do: assign(socket, selected_view: view)

  defp maybe_scroll_to_target_resource(socket, nil, _full_hierarchy, _selected_view), do: socket

  defp maybe_scroll_to_target_resource(socket, resource_id, full_hierarchy, nil),
    do: scroll_to_target_resource(socket, resource_id, full_hierarchy, @default_selected_view)

  defp maybe_scroll_to_target_resource(socket, resource_id, full_hierarchy, selected_view),
    do: scroll_to_target_resource(socket, resource_id, full_hierarchy, selected_view)
end
