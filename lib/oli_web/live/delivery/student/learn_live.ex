defmodule OliWeb.Delivery.Student.LearnLive do
  use OliWeb, :live_view

  alias Oli.Accounts.User
  alias OliWeb.Common.FormatDateTime
  alias Oli.Delivery.{Metrics, Sections}
  alias Phoenix.LiveView.JS
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.SectionCache
  alias OliWeb.Common.Utils, as: WebUtils
  alias OliWeb.Components.Delivery.Student
  alias OliWeb.Delivery.Student.Utils
  alias Oli.Publishing.DeliveryResolver
  alias Phoenix.LiveView.JS

  import Oli.Utils, only: [get_in: 3]
  import Ecto.Query, warn: false, only: [from: 2]

  @default_selected_view :gallery

  @default_image "/images/course_default.jpg"
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
         :contains_deliberate_practice
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
        units: get_or_compute_full_hierarchy(section)["children"],
        selected_module_per_unit_resource_id: %{},
        student_end_date_exceptions_per_resource_id: %{},
        student_visited_pages: %{},
        student_progress_per_resource_id: %{},
        student_raw_avg_score_per_page_id: %{},
        student_raw_avg_score_per_container_id: %{},
        viewed_intro_video_resource_ids:
          get_viewed_intro_video_resource_ids(
            section.slug,
            socket.assigns.current_user.id
          ),
        assistant_enabled: Sections.assistant_enabled?(section),
        display_props_per_module_id: %{},
        selected_view: @default_selected_view
      )
      |> slim_assigns()

    {:ok, socket, temporary_assigns: [units: [], unit_resource_ids: []]}
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

    case params do
      %{"selected_view" => selected_view, "target_resource_id" => resource_id} ->
        selected_view = String.to_existing_atom(selected_view)

        {:noreply,
         socket
         |> assign(selected_view: selected_view)
         |> update(:units, fn _units -> full_hierarchy["children"] end)
         |> maybe_enable_gallery_slider_buttons(full_hierarchy, selected_view)
         |> scroll_to_target_resource(resource_id, full_hierarchy, selected_view)}

      %{"selected_view" => selected_view} ->
        selected_view = String.to_existing_atom(selected_view)

        {:noreply,
         socket
         |> assign(selected_view: selected_view)
         |> update(:units, fn _units -> full_hierarchy["children"] end)
         |> maybe_enable_gallery_slider_buttons(full_hierarchy, selected_view)}

      %{"target_resource_id" => resource_id} ->
        {:noreply,
         socket
         |> maybe_enable_gallery_slider_buttons(full_hierarchy, :gallery)
         |> scroll_to_target_resource(resource_id, full_hierarchy, :gallery)}

      _ ->
        {:noreply, socket}
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
          offset: 10,
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
          offset: 80,
          pulse: true,
          pulse_delay: 500
        })

      %{resource_type_id: resource_type_id, numbering_level: 2}
      when resource_type_id == @container_resource_type_id ->
        # the target is a module, so we scroll in the Y direction to the unit that is parent of that module,
        # and then scroll X in the slider to that module and expand it

        module_resource_id = String.to_integer(resource_id)

        unit_resource_id =
          Oli.Delivery.Hierarchy.find_parent_in_hierarchy(
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
        |> push_event("scroll-y-to-target", %{id: "unit_#{unit_resource_id}", offset: 80})
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
          offset: 80,
          pulse: true,
          pulse_delay: 500
        })

      %{resource_type_id: resource_type_id, numbering_level: 2}
      when resource_type_id == @page_resource_type_id ->
        # the target is a page at a module level, so we scroll in the Y direction to the unit that is parent of that page,
        # and then scroll X in the slider to that page

        unit_resource_id =
          Oli.Delivery.Hierarchy.find_parent_in_hierarchy(
            full_hierarchy,
            fn node -> node["resource_id"] == String.to_integer(resource_id) end
          )["resource_id"]

        socket
        |> push_event("scroll-y-to-target", %{id: "unit_#{unit_resource_id}", offset: 80})
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
          find_module_ancestor(
            full_hierarchy,
            String.to_integer(resource_id),
            @container_resource_type_id
          )

        unit_resource_id =
          Oli.Delivery.Hierarchy.find_parent_in_hierarchy(
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
        |> push_event("scroll-y-to-target", %{id: "unit_#{unit_resource_id}", offset: 80})
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
        Oli.Delivery.Hierarchy.find_parent_in_hierarchy(
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
     |> update(:units, fn units -> [selected_unit | units] end)
     |> push_event("play_video", %{"video_url" => video_url})}
  end

  def handle_event("change_selected_view", %{"selected_view" => selected_view}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/sections/#{socket.assigns.section.slug}/learn?#{%{selected_view: selected_view}}"
     )}
  end

  def handle_event(
        "select_module",
        %{"unit_resource_id" => unit_resource_id, "module_resource_id" => module_resource_id},
        socket
      ) do
    {:noreply, select_module(socket, unit_resource_id, module_resource_id)}
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
      Oli.Delivery.Hierarchy.find_parent_in_hierarchy(
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
     |> update(:units, fn units -> [selected_unit | units] end)}
  end

  ## Tab navigation start ##

  def handle_event("intro_card_keydown", params, socket) do
    case params["key"] do
      "Enter" ->
        {:noreply, push_event(socket, "play_video", %{"video_url" => params["video_url"]})}

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
          select_module(socket, params["unit_resource_id"], params["module_resource_id"])
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

  defp select_module(socket, unit_resource_id, module_resource_id) do
    unit_resource_id = String.to_integer(unit_resource_id)
    module_resource_id = String.to_integer(module_resource_id)
    full_hierarchy = get_or_compute_full_hierarchy(socket.assigns.section)

    selected_unit =
      Oli.Delivery.Hierarchy.find_parent_in_hierarchy(
        full_hierarchy,
        fn node -> node["resource_id"] == module_resource_id end
      )

    current_selected_module_for_unit =
      Map.get(
        socket.assigns.selected_module_per_unit_resource_id,
        unit_resource_id
      )

    {selected_module_per_unit_resource_id, expand_module?} =
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
               |> fetch_learning_objectives(socket.assigns.section.id)
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
                 |> fetch_learning_objectives(socket.assigns.section.id)
             }), true}
          end
      end

    send(self(), :gc)

    socket
    |> assign(selected_module_per_unit_resource_id: selected_module_per_unit_resource_id)
    |> update(:units, fn units -> [selected_unit | units] end)
    |> maybe_scroll_y_to_unit(unit_resource_id, expand_module?)
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
     push_redirect(socket,
       to:
         resource_url(
           values["slug"],
           section_slug,
           resource_id,
           selected_view
         )
     )}
  end

  def select_module(js \\ %JS{}, unit_resource_id) do
    js
    |> JS.hide(
      to: "#selected_module_in_unit_#{unit_resource_id}",
      transition: {"ease-out duration-500", "opacity-100", "opacity-0"}
    )
    |> JS.push("select_module")
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

    full_hierarchy = get_or_compute_full_hierarchy(section)

    send(self(), :gc)

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
     |> update(:units, fn _units -> full_hierarchy["children"] end)
     |> maybe_enable_gallery_slider_buttons(full_hierarchy, selected_view)}
  end

  # needed to ignore results of Task invocation
  def handle_info(_, socket), do: {:noreply, socket}

  def render(%{selected_view: :outline} = assigns) do
    %{
      units: units,
      student_visited_pages: student_visited_pages,
      student_raw_avg_score_per_page_id: student_raw_avg_score_per_page_id,
      student_progress_per_resource_id: student_progress_per_resource_id,
      section: %{id: section_id}
    } = assigns

    units_with_metrics =
      units
      |> Enum.map(fn unit ->
        unit
        |> mark_visited_and_completed_pages(
          student_visited_pages,
          student_raw_avg_score_per_page_id,
          student_progress_per_resource_id
        )
        |> fetch_learning_objectives(section_id)
      end)

    assigns =
      Map.merge(assigns, %{
        units: units_with_metrics
      })

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
      <div id="outline_rows" phx-update="append">
        <.outline_row
          :for={row <- @units}
          row={row}
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
      <div id="all_units_as_gallery" phx-update="append">
        <.gallery_row
          :for={unit <- @units}
          unit={unit}
          ctx={@ctx}
          student_progress_per_resource_id={@student_progress_per_resource_id}
          student_end_date_exceptions_per_resource_id={@student_end_date_exceptions_per_resource_id}
          selected_module_per_unit_resource_id={@selected_module_per_unit_resource_id}
          student_raw_avg_score_per_page_id={@student_raw_avg_score_per_page_id}
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
            <h3 class="text-[26px] leading-[32px] tracking-[0.02px] font-normal dark:text-[#DDD]">
              <%= @unit["title"] %>
            </h3>
            <div class="flex items-center w-full gap-3">
              <div class="flex items-center gap-3" role="schedule_details">
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
              <div class="ml-auto flex items-center gap-6">
                <Student.score_summary :if={@progress == 100} raw_avg_score={@unit_raw_avg_score} />
                <.progress_bar
                  percent={@progress}
                  width="100px"
                  on_going_colour="bg-[#0CAF61]"
                  completed_colour="bg-[#0CAF61]"
                  role={"unit_#{@unit["numbering"]["index"]}_progress"}
                  show_percent={@progress != 100}
                />
                <svg
                  :if={@progress == 100}
                  xmlns="http://www.w3.org/2000/svg"
                  width="25"
                  height="24"
                  viewBox="0 0 25 24"
                  fill="none"
                  role="unit completed check icon"
                >
                  <path
                    d="M10.0496 17.9996L4.34961 12.2996L5.77461 10.8746L10.0496 15.1496L19.2246 5.97461L20.6496 7.39961L10.0496 17.9996Z"
                    fill="#0CAF61"
                  />
                </svg>
              </div>
            </div>
          </div>
        </div>
        <div class="w-[294px]">
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
            <%= "UNIT #{@unit["numbering"]["index"]}" %>
          </div>
          <div class="mb-6 flex flex-col items-start gap-[6px] w-full">
            <h3 class="text-[26px] leading-[32px] tracking-[0.02px] font-normal dark:text-[#DDD]">
              <%= @unit["title"] %>
            </h3>
            <div class="flex items-center w-full gap-3">
              <div class="flex items-center gap-3" role="schedule_details">
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
              <div class="ml-auto flex items-center gap-6">
                <Student.score_summary :if={@progress == 100} raw_avg_score={@unit_raw_avg_score} />
                <.progress_bar
                  percent={@progress}
                  width="100px"
                  on_going_colour="bg-[#0CAF61]"
                  completed_colour="bg-[#0CAF61]"
                  role={"unit_#{@unit["numbering"]["index"]}_progress"}
                  show_percent={@progress != 100}
                />
                <svg
                  :if={@progress == 100}
                  xmlns="http://www.w3.org/2000/svg"
                  width="25"
                  height="24"
                  viewBox="0 0 25 24"
                  fill="none"
                  role="unit completed check icon"
                >
                  <path
                    d="M10.0496 17.9996L4.34961 12.2996L5.77461 10.8746L10.0496 15.1496L19.2246 5.97461L20.6496 7.39961L10.0496 17.9996Z"
                    fill="#0CAF61"
                  />
                </svg>
              </div>
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
            class="overflow-x-scroll overflow-y-hidden h-[187px] pt-[5px] px-[5px] scrollbar-hide"
          >
            <.custom_focus_wrap
              id={"slider_focus_wrap_#{@unit["resource_id"]}"}
              initially_enabled={false}
              class="flex"
            >
              <.intro_video_card
                :if={@unit["intro_video"]}
                video_url={@unit["intro_video"]}
                card_resource_id={@unit["resource_id"]}
                resource_id={@unit["resource_id"]}
                intro_video_viewed={@unit["resource_id"] in @viewed_intro_video_resource_ids}
                is_youtube_video={WebUtils.is_youtube_video?(@unit["intro_video"])}
                unit_resource_id={@unit["resource_id"]}
              />
              <.card
                :for={module <- @unit["children"]}
                card={module}
                module_index={module["numbering"]["index"]}
                unit_resource_id={@unit["resource_id"]}
                unit_numbering_index={@unit["numbering"]["index"]}
                bg_image_url={module["poster_image"]}
                student_progress_per_resource_id={@student_progress_per_resource_id}
                selected={
                  @selected_module_per_unit_resource_id[@unit["resource_id"]]["resource_id"] ==
                    module["resource_id"]
                }
              />
            </.custom_focus_wrap>
          </div>
        </div>
      </div>
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
              Module <%= Map.get(@selected_module_per_unit_resource_id, @unit["resource_id"])[
                "numbering"
              ]["index"] %>
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
          class="flex flex-col max-w-[760px] pt-[25px] pb-2.5 justify-start items-start gap-[23px] inline-flex w-full"
        >
          <div class="w-full">
            <% module =
              Map.get(assigns.selected_module_per_unit_resource_id, assigns.unit["resource_id"]) %>
            <.module_content_header
              module={module}
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
        <div role="collapse_bar" class="flex items-center justify-center py-[6px] px-[10px] mt-6">
          <span class="w-1/2 rounded-lg h-[2px] bg-gray-600/10 dark:bg-[#D9D9D9] dark:bg-opacity-10">
          </span>
          <div class="text-gray-600/10 dark:text-[#D9D9D9] dark:text-opacity-10 flex items-center justify-center px-[44px]">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="12"
              height="6"
              viewBox="0 0 12 6"
              fill="currentColor"
              role="up_arrow"
            >
              <path d="M6 0L0 6H12L6 0Z" fill="currentColor" />
            </svg>
          </div>
          <span class="w-1/2 rounded-lg h-[2px] bg-gray-600/10 dark:bg-[#D9D9D9] dark:bg-opacity-10">
          </span>
        </div>
      </.custom_focus_wrap>
    </div>
    """
  end

  def outline_row(%{type: :unit} = assigns) do
    ~H"""
    <div id={"unit_#{@row["resource_id"]}"}>
      <div class="md:p-[25px] md:pl-[125px] md:pr-[175px]" role={"row_#{@row["numbering"]["index"]}"}>
        <div class="flex flex-col md:flex-row md:gap-[30px]">
          <div class="dark:text-white text-xl font-bold font-['Open Sans']">
            <%= "Unit #{@row["numbering"]["index"]}: #{@row["title"]}" %>
          </div>
        </div>
        <div class="flex flex-col mt-6">
          <.outline_row
            :for={row <- @row["children"]}
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
          module_resource_id={@row["resource_id"]}
          video_url={@row["intro_video"]}
          intro_video_viewed={@row["resource_id"] in @viewed_intro_video_resource_ids}
          view={:outline}
        />
        <.outline_row
          :for={row <- @row["children"]}
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
          "w-full pl-[5px] pr-[7px] py-2.5 rounded-lg justify-start items-center gap-5 flex rounded-lg focus:bg-[#000000]/5 hover:bg-[#000000]/5 dark:focus:bg-[#FFFFFF]/5 dark:hover:bg-[#FFFFFF]/5",
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

              <.duration_in_minutes
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

  def module_content_header(assigns) do
    ~H"""
    <div class="w-full border-b dark:border-white/20 flex items-center justify-between pb-1.5">
      <div role="completed count" class="flex gap-2.5">
        <div class="w-7 h-8 py-1 flex gap-2.5">
          <.check_icon />
        </div>
        <div class="w-34 h-8 pl-1 flex gap-1.5">
          <div class="flex gap-0.5 items-center">
            <span class="opacity-80 dark:text-white text-[13px] font-normal font-['Open Sans'] leading-loose">
              <%= case count_completed_and_total_pages(@module) do
                {1, 1} -> "1 of 1 Page"
                {completed_count, total_count} -> "#{completed_count} of #{total_count} Pages"
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
        <div class="w-7 h-8 py-1 flex gap-2.5">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="currentColor"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            class={if @show_completed_pages, do: "", else: "rotate-180"}
          >
            <path d="M12 8l-6 6h12l-6-6z" />
          </svg>
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

  attr :module, :map
  attr :student_raw_avg_score_per_page_id, :map
  attr :student_end_date_exceptions_per_resource_id, :map
  attr :ctx, :map
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
            show_completed_pages
          )
      })

    ~H"""
    <div
      id={"index_for_#{@module["resource_id"]}"}
      class="relative flex flex-col gap-[25px] items-start"
    >
      <div
        :if={@module["learning_objectives"] != []}
        phx-click-away={JS.hide(to: "#learning_objectives_#{@module["resource_id"]}")}
        class="hidden flex-col gap-3 w-full p-6 bg-white dark:bg-[#242533] shadow-xl rounded-xl absolute top-[35px] left-0 z-50"
        id={"learning_objectives_#{@module["resource_id"]}"}
        role="learning objectives tooltip"
      >
        <svg
          class="absolute -top-[8px] left-[8px] w-[27px] h-3 fill-white dark:fill-[#242533] -rotate-90"
          xmlns="http://www.w3.org/2000/svg"
          width="12"
          height="27"
          viewBox="0 0 12 27"
          fill="none"
        >
          <path d="M12 13.5L0 27L-1.18021e-06 1.90735e-06L12 13.5Z" />
        </svg>
        <div class="flex items-center gap-[10px] mb-3">
          <h3 class="text-[12px] leading-[16px] tracking-[0.96px] dark:opacity-40 font-bold uppercase dark:text-white">
            Learning Objectives
          </h3>
          <button
            phx-click={JS.hide(to: "#learning_objectives_#{@module["resource_id"]}")}
            tabindex="0"
            class="ml-auto cursor-pointer hover:opacity-50 hover:scale-105"
          >
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
              <path
                class="stroke-black dark:stroke-white"
                d="M6 18L18 6M6 6L18 18"
                stroke-width="2"
                stroke-linejoin="round"
              />
            </svg>
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
        class="flex items-center gap-[14px] px-[10px] w-full p-1 cursor-pointer"
        phx-click={JS.toggle(to: "#learning_objectives_#{@module["resource_id"]}", display: "flex")}
      >
        <svg
          class="fill-black dark:fill-white"
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
        >
          <path
            opacity="0.5"
            fill-rule="evenodd"
            clip-rule="evenodd"
            d="M20.5 15L23.5 12L20.5 9V5C20.5 4.45 20.3042 3.97917 19.9125 3.5875C19.5208 3.19583 19.05 3 18.5 3H4.5C3.95 3 3.47917 3.19583 3.0875 3.5875C2.69583 3.97917 2.5 4.45 2.5 5V19C2.5 19.55 2.69583 20.0208 3.0875 20.4125C3.47917 20.8042 3.95 21 4.5 21H18.5C19.05 21 19.5208 20.8042 19.9125 20.4125C20.3042 20.0208 20.5 19.55 20.5 19V15ZM10.5 14.15H12.35C12.35 13.8667 12.3625 13.625 12.3875 13.425C12.4125 13.225 12.4667 13.0333 12.55 12.85C12.6333 12.6667 12.7375 12.4958 12.8625 12.3375C12.9875 12.1792 13.1667 11.9833 13.4 11.75C13.9833 11.1667 14.3958 10.6792 14.6375 10.2875C14.8792 9.89583 15 9.45 15 8.95C15 8.06667 14.7 7.35417 14.1 6.8125C13.5 6.27083 12.6917 6 11.675 6C10.7583 6 9.97917 6.225 9.3375 6.675C8.69583 7.125 8.25 7.75 8 8.55L9.65 9.2C9.76667 8.75 10 8.3875 10.35 8.1125C10.7 7.8375 11.1083 7.7 11.575 7.7C12.025 7.7 12.4 7.82083 12.7 8.0625C13 8.30417 13.15 8.625 13.15 9.025C13.15 9.30833 13.0583 9.60833 12.875 9.925C12.6917 10.2417 12.3833 10.5917 11.95 10.975C11.6667 11.2083 11.4375 11.4375 11.2625 11.6625C11.0875 11.8875 10.9417 12.125 10.825 12.375C10.7083 12.625 10.625 12.8875 10.575 13.1625C10.525 13.4375 10.5 13.7667 10.5 14.15ZM11.4 18C11.75 18 12.0458 17.8792 12.2875 17.6375C12.5292 17.3958 12.65 17.1 12.65 16.75C12.65 16.4 12.5292 16.1042 12.2875 15.8625C12.0458 15.6208 11.75 15.5 11.4 15.5C11.05 15.5 10.7542 15.6208 10.5125 15.8625C10.2708 16.1042 10.15 16.4 10.15 16.75C10.15 17.1 10.2708 17.3958 10.5125 17.6375C10.7542 17.8792 11.05 18 11.4 18Z"
          />
        </svg>
        <h3 class="text-[16px] leading-[22px] font-semibold dark:text-white">
          Introduction and Learning Objectives
        </h3>
      </button>
      <.intro_video_item
        :if={module_has_intro_video(@module)}
        duration_minutes={@module["duration_minutes"]}
        module_resource_id={@module["resource_id"]}
        video_url={@module["intro_video"]}
        intro_video_viewed={@intro_video_viewed}
      />
      <div
        :for={grouped_due_date <- @page_due_dates}
        class="flex flex-col w-full"
        id={"pages_grouped_by_#{grouped_due_date}"}
      >
        <div class="h-[19px] mb-5">
          <span class="dark:text-white text-sm font-bold font-['Open Sans']">
            <%= "Due: #{format_date(grouped_due_date, @ctx, "{WDshort} {Mshort} {D}, {YYYY}")}" %>
          </span>
        </div>
        <.index_item
          :for={child <- @module["children"]}
          :if={
            display_module_item?(
              @show_completed_pages,
              grouped_due_date,
              @student_end_date_exceptions_per_resource_id,
              child
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
  attr :ctx, :map
  attr :graded, :boolean
  attr :raw_avg_score, :map
  attr :student_raw_avg_score_per_page_id, :map
  attr :student_end_date_exceptions_per_resource_id, :map
  attr :student_progress_per_resource_id, :map
  attr :due_date, Date
  attr :parent_due_date, Date
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
          @student_end_date_exceptions_per_resource_id,
          @section_attrs
        )
      }
      role={"#{@type} #{@numbering_index} details"}
      class="w-full pl-[5px] pr-[7px] py-2.5 rounded-lg justify-start items-center gap-5 flex rounded-lg"
      id={"index_item_#{@resource_id}_#{@parent_due_date}"}
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
            @student_end_date_exceptions_per_resource_id,
            child
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
        "w-full pl-[5px] pr-[7px] py-2.5 rounded-lg justify-start items-center gap-5 flex rounded-lg focus:bg-[#000000]/5 hover:bg-[#000000]/5 dark:focus:bg-[#FFFFFF]/5 dark:hover:bg-[#FFFFFF]/5",
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

            <.duration_in_minutes duration_minutes={@duration_minutes} graded={@graded} />
          </div>
          <div :if={@graded} role="due date and score" class="flex">
            <span class="opacity-60 text-[13px] font-normal font-['Open Sans'] !font-normal opacity-60 dark:text-white">
              Due: <%= format_date(@due_date, @ctx, "{WDshort} {Mshort} {D}, {YYYY}") %>
            </span>
            <Student.score_summary raw_avg_score={@raw_avg_score} />
          </div>
        </div>
      </div>
    </button>
    """
  end

  attr :graded, :boolean, default: false
  attr :duration_minutes, :integer

  def duration_in_minutes(assigns) do
    ~H"""
    <div class="ml-auto items-center gap-1.5 flex">
      <div :if={@graded} class="w-[22px] h-[22px] opacity-60 flex items-center justify-center">
        <.clock_icon />
      </div>
      <div class="text-right dark:text-white opacity-60 whitespace-nowrap">
        <span class="text-sm font-semibold font-['Open Sans']" role="duration in minutes">
          <%= parse_minutes(@duration_minutes) %>
          <span class="w-[25px] self-stretch text-[13px] font-semibold font-['Open Sans']">
            min
          </span>
        </span>
      </div>
    </div>
    """
  end

  attr :duration_minutes, :integer
  attr :module_resource_id, :integer
  attr :intro_video_viewed, :boolean
  attr :video_url, :string, default: nil
  attr :view, :atom, default: @default_selected_view

  def intro_video_item(assigns) do
    ~H"""
    <button
      role="intro video details"
      class="w-full pl-[5px] pr-[7px] py-2.5 rounded-lg justify-start items-center gap-5 flex rounded-lg focus:bg-[#000000]/5 hover:bg-[#000000]/5 dark:focus:bg-[#FFFFFF]/5 dark:hover:bg-[#FFFFFF]/5 font-normal hover:font-medium focus:font-medium"
      id={"intro_video_for_module_#{@module_resource_id}"}
      phx-click="play_video"
      phx-value-module_resource_id={@module_resource_id}
      phx-value-video_url={@video_url}
      phx-value-is_intro_video="false"
    >
      <div
        role={"#{if @intro_video_viewed, do: "seen", else: "unseen"} video icon"}
        class="flex justify-center items-center h-7 w-7 shrink-0"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          class="fill-black dark:fill-white"
        >
          <path
            d="M9.5 16.5L16.5 12L9.5 7.5V16.5ZM4 20C3.45 20 2.97917 19.8042 2.5875 19.4125C2.19583 19.0208 2 18.55 2 18V6C2 5.45 2.19583 4.97917 2.5875 4.5875C2.97917 4.19583 3.45 4 4 4H20C20.55 4 21.0208 4.19583 21.4125 4.5875C21.8042 4.97917 22 5.45 22 6V18C22 18.55 21.8042 19.0208 21.4125 19.4125C21.0208 19.8042 20.55 20 20 20H4Z"
            class={[
              "opacity-60",
              if(@intro_video_viewed, do: "!opacity-100 fill-[#0CAF61] dark:fill-[#12E56A]")
            ]}
          />
        </svg>
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

            <.duration_in_minutes duration_minutes={@duration_minutes} />
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
    case {assigns.was_visited, assigns.item_type, assigns.graded, assigns.raw_avg_score} do
      {true, "page", false, _} ->
        # visited practice page (check icon shown when progress = 100%)
        ~H"""
        <.check_icon progress={@progress} />
        """

      {false, "page", false, _} ->
        # not visited practice page
        ~H"""
        <.no_icon />
        """

      {true, "page", true, raw_avg_score} when not is_nil(raw_avg_score) ->
        # completed graded page
        ~H"""
        <div role="square check icon" class="flex justify-center items-center w-[22px] h-[22px] shrink-0">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path
              d="M5 21C4.45 21 3.97917 20.8042 3.5875 20.4125C3.19583 20.0208 3 19.55 3 19V5C3 4.45 3.19583 3.97917 3.5875 3.5875C3.97917 3.19583 4.45 3 5 3H17.925L15.925 5H5V19H19V12.05L21 10.05V19C21 19.55 20.8042 20.0208 20.4125 20.4125C20.0208 20.8042 19.55 21 19 21H5Z"
              class="fill-[#0CAF61] dark:fill-[#12E56A]"
            />
            <path
              d="M11.7 16.025L6 10.325L7.425 8.9L11.7 13.175L20.875 4L22.3 5.425L11.7 16.025Z"
              class="fill-[#0CAF61] dark:fill-[#12E56A]"
            />
          </svg>
        </div>
        """

      {_, "page", true, _} ->
        # not completed graded page
        ~H"""
        <div role="orange flag icon" class="flex justify-center items-center w-[22px] h-[22px] shrink-0">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="currentColor"
            class="icon icon-tabler icons-tabler-filled icon-tabler-flag-3"
          >
            <path stroke="none" d="M0 0h24v24H0z" fill="none" />
            <path
              d="M19 4c.852 0 1.297 .986 .783 1.623l-.076 .084l-3.792 3.793l3.792 3.793c.603 .602 .22 1.614 -.593 1.701l-.114 .006h-13v6a1 1 0 0 1 -.883 .993l-.117 .007a1 1 0 0 1 -.993 -.883l-.007 -.117v-16a1 1 0 0 1 .883 -.993l.117 -.007h14z"
              fill="#FF9040"
            />
          </svg>
        </div>
        """
    end
  end

  attr :title, :string, default: "Intro"
  attr :video_url, :string
  attr :card_resource_id, :string
  attr :resource_id, :string
  attr :intro_video_viewed, :boolean, default: false
  attr :is_youtube_video, :boolean, default: false
  attr :unit_resource_id, :string

  def intro_video_card(%{is_youtube_video: true} = assigns) do
    ~H"""
    <div
      id={"intro_card_#{@card_resource_id}"}
      class="relative slider-card hover:scale-[1.01] mr-4"
      role="youtube_intro_video_card"
      phx-keydown="intro_card_keydown"
      phx-value-video_url={@video_url}
      phx-value-card_resource_id={@card_resource_id}
      data-event={leave_unit(@unit_resource_id)}
      phx-click="play_video"
      phx-value-video_url={@video_url}
      phx-value-module_resource_id={@resource_id}
      phx-value-is_intro_video="true"
    >
      <div class="rounded-xl absolute overflow-hidden h-[170px] w-[294px] cursor-pointer bg-[linear-gradient(180deg,#223_0%,rgba(34,34,51,0.72)_52.6%,rgba(34,34,51,0.00)_100%)]">
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
        <h5 class="text-[13px] leading-[18px] font-bold opacity-60 text-gray-500 text-white dark:text-opacity-50 self-start">
          <%= @title %>
        </h5>
        <div
          id={"intro_video_card_#{@card_resource_id}"}
          class="w-[70px] h-[70px] relative my-auto -top-2 cursor-pointer"
        >
          <div class="w-full h-full rounded-full backdrop-blur bg-gray/50"></div>
          <div
            role="play_unit_intro_video"
            class="w-full h-full absolute top-0 left-0 flex items-center justify-center"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="white"
              width="33"
              height="38"
              viewBox="0 0 16.984 24.8075"
              class="scale-110 ml-[6px] mt-[9px]"
            >
              <path d="M0.759,0.158c0.39-0.219,0.932-0.21,1.313,0.021l14.303,8.687c0.368,0.225,0.609,0.625,0.609,1.057   s-0.217,0.832-0.586,1.057L2.132,19.666c-0.382,0.231-0.984,0.24-1.375,0.021C0.367,19.468,0,19.056,0,18.608V1.237   C0,0.79,0.369,0.378,0.759,0.158z" />
            </svg>
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
      class="relative slider-card hover:scale-[1.01] mr-4"
      role="intro_video_card"
      phx-keydown="intro_card_keydown"
      phx-value-video_url={@video_url}
      phx-value-card_resource_id={@card_resource_id}
      data-event={leave_unit(@unit_resource_id)}
      phx-click="play_video"
      phx-value-video_url={@video_url}
      phx-value-module_resource_id={@resource_id}
      phx-value-is_intro_video="true"
    >
      <div class="rounded-xl absolute overflow-hidden -top-[0.7px] -left-[0.7px] h-[170px] w-[294px] cursor-pointer bg-[linear-gradient(180deg,#223_0%,rgba(34,34,51,0.72)_52.6%,rgba(34,34,51,0.00)_100%)]">
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
      <div class="relative flex flex-col items-center rounded-xl h-[170px] w-[294px] bg-gray-200/50 shrink-0 px-5 pt-[15px] bg-cover bg-center">
        <video
          id={"video_preview_image_#{@video_url}"}
          class="rounded-xl object-cover absolute -top-[0.7px] -left-[0.7px] h-[170px] w-[294px]"
          preload="metadata"
        >
          <source src={"#{@video_url}#t=0.5"} /> Your browser does not support the video tag.
        </video>
        <h5 class="z-30 text-[13px] leading-[18px] font-bold opacity-60 text-gray-500 text-white dark:text-opacity-50 self-start">
          <%= @title %>
        </h5>
        <div
          id={"intro_video_card_#{@card_resource_id}"}
          class="w-[70px] h-[70px] relative my-auto -top-2 cursor-pointer"
        >
          <div class="w-full h-full rounded-full backdrop-blur bg-gray/50"></div>
          <div
            role="play_unit_intro_video"
            class="z-30 w-full h-full absolute top-0 left-0 flex items-center justify-center"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="white"
              width="33"
              height="38"
              viewBox="0 0 16.984 24.8075"
              class="scale-110 ml-[6px] mt-[9px]"
            >
              <path d="M0.759,0.158c0.39-0.219,0.932-0.21,1.313,0.021l14.303,8.687c0.368,0.225,0.609,0.625,0.609,1.057   s-0.217,0.832-0.586,1.057L2.132,19.666c-0.382,0.231-0.984,0.24-1.375,0.021C0.367,19.468,0,19.056,0,18.608V1.237   C0,0.79,0.369,0.378,0.759,0.158z" />
            </svg>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :card, :map
  attr :module_index, :integer
  attr :unit_numbering_index, :integer
  attr :unit_resource_id, :string
  attr :selected, :boolean, default: false
  attr :bg_image_url, :string, doc: "the background image url for the card"
  attr :student_progress_per_resource_id, :map
  attr :default_image, :string, default: @default_image

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
          else: "select_module"
      }
      phx-keydown="card_keydown"
      phx-value-unit_resource_id={@unit_resource_id}
      phx-value-module_resource_id={@card["resource_id"]}
      phx-value-slug={@card["slug"]}
      phx-value-type={if @is_page, do: "page", else: "module"}
      class={[
        "relative slider-card hover:scale-[1.01] transition-transform duration-150 mr-4",
        if(!@is_page, do: "slider-card")
      ]}
      role={"card_#{@module_index}"}
      data-enter-event={enter_module(@unit_resource_id)}
      data-leave-event={leave_unit(@unit_resource_id)}
    >
      <div class="rounded-xl absolute h-[170px] w-[294px] overflow-hidden cursor-pointer bg-[linear-gradient(180deg,#223_0%,rgba(34,34,51,0.72)_52.6%,rgba(34,34,51,0.00)_100%)]">
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
      <.page_icon :if={@is_page} graded={@card["graded"]} />

      <div class="h-[170px] w-[294px]">
        <div
          class={[
            "flex flex-col gap-[5px] cursor-pointer rounded-xl h-[170px] w-[294px] shrink-0 mb-1 px-5 pt-[15px] bg-gray-200 z-10 bg-cover bg-center",
            if(@selected,
              do: "bg-gray-400 outline outline-[3px] outline-gray-800 dark:outline-white"
            )
          ]}
          style={"background-image: url('#{if(@bg_image_url in ["", nil], do: @default_image, else: @bg_image_url)}');"}
        >
          <span class="text-[12px] leading-[16px] font-bold opacity-60 text-white dark:text-opacity-50">
            <%= if @is_page,
              do: Phoenix.HTML.raw("&nbsp;"),
              else: "#{@unit_numbering_index}.#{@module_index}" %>
          </span>
          <h5 class="text-[18px] leading-[25px] font-bold text-white z-10">
            <%= @card["title"] %>
          </h5>
        </div>
        <div
          :if={@selected}
          class={[
            "flex justify-center items-center -mt-1"
          ]}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="27"
            height="12"
            viewBox="0 0 27 12"
            fill="currentColor"
          >
            <path d="M0 0L27 0L13.5 12Z" />
          </svg>
        </div>
      </div>
    </div>
    """
  end

  attr :graded, :boolean

  def page_icon(assigns) do
    if assigns.graded do
      ~H"""
      <div
        class="h-[36px] w-[36px] absolute top-0 right-0 bg-[#F68E2E] rounded-bl-xl rounded-tr-xl"
        role="graded page icon"
      >
        <div class="absolute top-0 right-0 h-[36px] w-[36px] flex justify-center items-center">
          <svg xmlns="http://www.w3.org/2000/svg" width="25" height="24" viewBox="0 0 25 24" fill="none">
            <path d="M5.5 21V4H14.5L14.9 6H20.5V16H13.5L13.1 14H7.5V21H5.5Z" fill="white" />
          </svg>
        </div>
      </div>
      """
    else
      ~H"""
      <div class="h-[45px] w-[36px] absolute top-0 right-0" role="page icon">
        <img src={~p"/images/course_content/page_icon.png"} />
        <div class="absolute top-0 right-0 h-[36px] w-[36px] flex justify-center items-center">
          <svg xmlns="http://www.w3.org/2000/svg" width="18" height="20" viewBox="0 0 18 20" fill="none">
            <path
              d="M3.34359 15.9558C2.54817 15.1604 1.89985 14.3023 1.39862 13.3816C0.897394 12.4608 0.537819 11.5183 0.319895 10.554C0.107418 9.58968 0.0338689 8.64171 0.0992462 7.71008C0.170072 6.77846 0.382548 5.90131 0.736675 5.07865C1.09625 4.25053 1.59203 3.51776 2.22401 2.88034C2.88323 2.22111 3.63507 1.71989 4.47952 1.37666C5.32943 1.03343 6.22292 0.842744 7.15999 0.804607C8.09707 0.761023 9.03414 0.864537 9.97122 1.11515C10.9083 1.36576 11.7963 1.75258 12.6353 2.2756L11.2216 3.66486C10.6223 3.34342 9.97939 3.10098 9.29293 2.93754C8.61191 2.76865 7.92545 2.69782 7.23354 2.72506C6.54708 2.74686 5.88786 2.88034 5.25588 3.1255C4.62935 3.37067 4.06819 3.74114 3.57241 4.23691C2.93499 4.87434 2.49096 5.62891 2.24035 6.5006C1.99519 7.3723 1.92981 8.2903 2.04422 9.25462C2.15863 10.2189 2.43921 11.1642 2.88595 12.0904C3.33815 13.0165 3.94016 13.8555 4.692 14.6074C5.15509 15.0759 5.63725 15.4709 6.13847 15.7923C6.64515 16.1138 7.1382 16.3753 7.61763 16.5769C8.09707 16.7839 8.54109 16.9446 8.94969 17.059C9.36375 17.1789 9.71243 17.2715 9.99573 17.3369C10.2954 17.4132 10.5187 17.533 10.6658 17.6965C10.8184 17.8654 10.8919 18.0833 10.8865 18.3502C10.8756 18.6608 10.7557 18.8896 10.5269 19.0367C10.2981 19.1892 10.0012 19.2383 9.63616 19.1838C9.33106 19.1402 8.94152 19.0558 8.46754 18.9305C7.999 18.8052 7.47598 18.6199 6.89848 18.3748C6.32643 18.135 5.73531 17.8163 5.12512 17.4186C4.51494 17.0209 3.92109 16.5333 3.34359 15.9558ZM6.63697 13.4061L8.68819 12.6215C9.11859 13.0465 9.60619 13.4006 10.151 13.6839C10.7013 13.9672 11.2706 14.1552 11.859 14.2478C12.4474 14.3404 13.0194 14.3132 13.5751 14.1661C14.1308 14.0135 14.6348 13.7112 15.087 13.259C15.5719 12.7795 15.8715 12.202 15.9859 11.5265C16.1058 10.8455 16.0595 10.1236 15.847 9.36086C15.6345 8.59267 15.2777 7.84084 14.7764 7.10534L16.1575 5.73242C16.7296 6.52784 17.16 7.34233 17.4487 8.17589C17.7429 9.00401 17.9009 9.81305 17.9227 10.603C17.9445 11.393 17.8301 12.1312 17.5795 12.8177C17.3343 13.4987 16.9557 14.098 16.4436 14.6156C15.9423 15.1168 15.3621 15.4873 14.7029 15.727C14.0491 15.9612 13.3572 16.0756 12.6272 16.0702C11.9026 16.0702 11.178 15.964 10.4534 15.7515C9.72877 15.539 9.03686 15.2339 8.37764 14.8362C7.72387 14.4385 7.14365 13.9618 6.63697 13.4061ZM8.35313 11.7716L6.38364 12.5153C6.24199 12.5698 6.10851 12.5398 5.9832 12.4254C5.86334 12.311 5.83338 12.1748 5.89331 12.0168L6.66149 10.0718L14.0982 2.64334L15.7898 4.33498L8.35313 11.7716ZM16.4191 3.7139L14.7274 2.02226L15.5119 1.23773C15.7244 1.0307 15.9696 0.91357 16.2474 0.886329C16.5307 0.859088 16.7623 0.938086 16.9421 1.12332L17.2363 1.40935C17.4487 1.62182 17.5441 1.87244 17.5223 2.16119C17.5059 2.44449 17.3915 2.69782 17.1791 2.9212L16.4191 3.7139Z"
              fill="white"
            />
          </svg>
        </div>
      </div>
      """
    end
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

  attr :progress, :float, default: 1.0

  defp check_icon(assigns) do
    ~H"""
    <div role="check icon" class="flex justify-center items-center w-[22px] h-[22px] shrink-0">
      <svg
        :if={@progress == 1.0}
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="icon icon-tabler icons-tabler-outline icon-tabler-check stroke-[#0CAF61] dark:stroke-[#12E56A]"
      >
        <path stroke="none" d="M0 0h24v24H0z" fill="none" />
        <path d="M5 12l5 5l10 -10" />
      </svg>
    </div>
    """
  end

  def clock_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="icon icon-tabler icons-tabler-outline icon-tabler-clock"
      role="clock icon"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" />
      <path d="M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0" />
      <path d="M12 7v5l3 3" />
    </svg>
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

  defp completed_page?(true = _graded, visited?, raw_avg_score, _progress),
    do: visited? and not is_nil(raw_avg_score)

  defp completed_page?(false = _graded, visited?, _score, progress),
    do: visited? and progress == 1.0

  defp count_completed_and_total_pages(container) do
    page_resource_type_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_resource_type_id = Oli.Resources.ResourceType.get_id_by_type("container")

    Enum.reduce(container["children"], {0, 0}, fn
      %{"resource_type_id" => ^page_resource_type_id} = page, {completed_count, total_count} ->
        {if(page["completed"], do: 1, else: 0) + completed_count, total_count + 1}

      %{"resource_type_id" => ^container_resource_type_id} = section,
      {completed_count, total_count} ->
        {completed, total} = count_completed_and_total_pages(section)

        {completed + completed_count, total + total_count}
    end)
  end

  defp display_module_item?(
         _show_completed_pages,
         _grouped_due_date,
         _student_end_date_exceptions_per_resource_id,
         %{"section_resource" => %{scheduling_type: :inclass_activity}} = _child
       ),
       do: false

  defp display_module_item?(
         show_completed_pages,
         grouped_due_date,
         student_end_date_exceptions_per_resource_id,
         child
       ) do
    if is_section?(child) do
      Enum.any?(
        child["children"],
        &display_module_item?(
          show_completed_pages,
          grouped_due_date,
          student_end_date_exceptions_per_resource_id,
          &1
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
        |> then(&if is_nil(&1), do: "Not yet scheduled", else: DateTime.to_date(&1))

      if show_completed_pages do
        student_due_date == grouped_due_date
      else
        !child["completed"] and student_due_date == grouped_due_date
      end
    end
  end

  # In-class Activities should not appear in the course content in the learn page (but only in the schedule) so we can ignore those.
  # As for 'read by' (lessons) and 'due date' (graded assignments) we assumed that we could group both together and treat the Read By Date as a general Due Date
  defp get_contained_pages_due_dates(
         container,
         student_end_date_exceptions_per_resource_id,
         show_completed_pages
       ) do
    contained_pages_due_dates(
      container,
      student_end_date_exceptions_per_resource_id,
      show_completed_pages
    )
    |> Enum.uniq()
    |> then(fn dates ->
      if nil in dates do
        dates
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(& &1, {:asc, Date})
        |> Enum.concat(["Not yet scheduled"])
      else
        Enum.sort_by(dates, & &1, {:asc, Date})
      end
    end)
  end

  defp contained_pages_due_dates(
         container,
         student_end_date_exceptions_per_resource_id,
         show_completed_pages
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
            Map.get(student_end_date_exceptions_per_resource_id, resource_id, end_date) &&
              DateTime.to_date(
                Map.get(student_end_date_exceptions_per_resource_id, resource_id, end_date)
              )
          ]
        end

      %{"resource_type_id" => ^container_type_id} = section_or_subsection ->
        contained_pages_due_dates(
          section_or_subsection,
          student_end_date_exceptions_per_resource_id,
          show_completed_pages
        )

      _ ->
        []
    end)
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

  defp parse_minutes(minutes) when minutes in ["", nil], do: "?"
  defp parse_minutes(minutes), do: minutes

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

  defp maybe_scroll_y_to_unit(socket, _unit_resource_id, false), do: socket

  defp maybe_scroll_y_to_unit(socket, unit_resource_id, true) do
    push_event(socket, "scroll-y-to-target", %{id: "unit_#{unit_resource_id}", offset: 80})
  end

  _docp = """
  When rendering learn page in gallery view, we need to execute the Scroller hook to enable the slider buttons
  """

  defp maybe_enable_gallery_slider_buttons(socket, full_hierarchy, :gallery) do
    push_event(socket, "enable-slider-buttons", %{
      unit_resource_ids:
        Enum.map(
          full_hierarchy["children"],
          & &1["resource_id"]
        )
    })
  end

  defp maybe_enable_gallery_slider_buttons(socket, _full_hierarchy, _selected_view), do: socket

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

  defp fetch_learning_objectives(module, section_id) do
    Map.merge(module, %{
      "learning_objectives" =>
        Sections.get_learning_objectives_for_container_id(
          section_id,
          module["resource_id"]
        )
    })
  end

  defp merge_target_module_as_selected(
         selected_module_per_unit_resource_id,
         section,
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
          |> fetch_learning_objectives(section.id)
      }
    )
  end

  def get_or_compute_full_hierarchy(section) do
    SectionCache.get_or_compute(section.slug, :full_hierarchy, fn ->
      full_hierarchy(section)
    end)
  end

  defp full_hierarchy(section) do
    {hierarchy_nodes, root_hierarchy_node} = hierarchy_nodes_by_sr_id(section)

    hierarchy_node_with_children(root_hierarchy_node, hierarchy_nodes)
  end

  defp hierarchy_node_with_children(
         %{"children" => children_ids} = node,
         nodes_by_sr_id
       ) do
    Map.put(
      node,
      "children",
      Enum.map(children_ids, fn sr_id ->
        Map.get(nodes_by_sr_id, sr_id)
        |> hierarchy_node_with_children(nodes_by_sr_id)
      end)
    )
  end

  # Returns a map of resource ids to hierarchy nodes and the root hierarchy node
  defp hierarchy_nodes_by_sr_id(section) do
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_id = Oli.Resources.ResourceType.get_id_by_type("container")

    labels =
      case section.customizations do
        nil -> Oli.Branding.CustomLabels.default_map()
        l -> Map.from_struct(l)
      end

    from(
      [s: s, sr: sr, rev: rev, spp: spp] in DeliveryResolver.section_resource_revisions(
        section.slug
      ),
      join: p in Project,
      on: p.id == spp.project_id,
      where:
        rev.resource_type_id == ^page_id or
          rev.resource_type_id == ^container_id,
      select: %{
        "id" => rev.id,
        "numbering" => %{
          "index" => sr.numbering_index,
          "level" => sr.numbering_level
        },
        "children" => sr.children,
        "resource_id" => rev.resource_id,
        "project_id" => sr.project_id,
        "project_slug" => p.slug,
        "title" => rev.title,
        "slug" => rev.slug,
        "graded" => rev.graded,
        "intro_video" => rev.intro_video,
        "poster_image" => rev.poster_image,
        "intro_content" => rev.intro_content,
        "duration_minutes" => rev.duration_minutes,
        "resource_type_id" => rev.resource_type_id,
        "section_resource" => sr,
        "is_root?" =>
          fragment(
            "CASE WHEN ? = ? THEN true ELSE false END",
            sr.id,
            s.root_section_resource_id
          )
      }
    )
    |> Oli.Repo.all()
    |> Enum.map(fn node ->
      numbering = Map.put(node["numbering"], "labels", labels)

      Map.put(node, "uuid", Oli.Utils.uuid())
      |> Map.put("numbering", numbering)
    end)
    |> Enum.reduce({%{}, nil}, fn item, {nodes, root} ->
      {
        Map.put(
          nodes,
          item["section_resource"].id,
          item
        ),
        if(item["is_root?"], do: item, else: root)
      }
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

  defp find_module_ancestor(_, nil, _), do: nil

  defp find_module_ancestor(hierarchy, resource_id, container_resource_type_id) do
    case Oli.Delivery.Hierarchy.find_parent_in_hierarchy(
           hierarchy,
           &(&1["resource_id"] == resource_id)
         ) do
      %{"resource_type_id" => ^container_resource_type_id, "numbering" => %{"level" => 2}} =
          module ->
        module["resource_id"]

      parent ->
        find_module_ancestor(hierarchy, parent["resource_id"], container_resource_type_id)
    end
  end
end
