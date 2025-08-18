defmodule OliWeb.Components.Delivery.PageNavigator do
  use Phoenix.LiveComponent

  alias OliWeb.PageDeliveryView
  alias OliWeb.Router.Helpers, as: Routes

  attr(:page_number, :integer, required: true)
  attr(:next_page, :map)
  attr(:previous_page, :map)
  attr(:preview_mode, :boolean, default: false)
  attr(:section_slug, :string, required: true)
  attr(:numbered_revisions, :list, required: true)
  attr(:show_navigation_arrows, :boolean, default: true)
  attr(:id, :string, required: true)

  def render(assigns) do
    assigns =
      assign(assigns, %{
        min_page: 1,
        max_page: assigns.numbered_revisions |> List.last() |> Map.get(:numbering_index, 1)
      })

    ~H"""
    <script>
      function handleInputFocus_<%= @id %>(focus = true) {
        const pageNavigator = document.getElementById("<%= @id %>");
        const pageNavigatorInput = pageNavigator.querySelector("input#<%= @id %>_input");
        const pageNavigatorButtons = pageNavigator.querySelectorAll("a");
        const pageNavigatorPopover = pageNavigator.querySelector("p#<%= @id %>_popover");

        for (button of pageNavigatorButtons) {
          if (focus) {
            button.classList.add("flex");
            button.classList.remove("hidden");
          } else {
            button.classList.add("hidden");
            button.classList.remove("flex");
          }
        }
        if (focus) {
          pageNavigator.classList.add("shadow-md");
          pageNavigatorPopover.classList.add("block");
          pageNavigatorPopover.classList.remove("hidden");
          pageNavigatorInput.select();
        } else {
          pageNavigator.classList.remove("shadow-md")
          pageNavigatorPopover.classList.add("hidden");
          pageNavigatorPopover.classList.remove("block");
          pageNavigatorInput.value = <%= @page_number %>;
        }
      }
    </script>

    <.form
      for={%{}}
      as={:page_number}
      action={Routes.page_delivery_path(OliWeb.Endpoint, :navigate_by_index, @section_slug)}
      id={@id}
      class="flex text-base hover:shadow-md rounded group relative"
    >
      <%= if @show_navigation_arrows and @previous_page do %>
        <a
          href={
            PageDeliveryView.previous_url(
              OliWeb.Endpoint,
              @previous_page,
              @preview_mode,
              @section_slug
            )
          }
          class="!no-underline rounded-l w-8 py-1 hidden group-hover:flex text-center cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-600"
        >
          <i class="fa-solid fa-chevron-left text-delivery-primary self-center mx-auto"></i>
        </a>
      <% end %>
      <input
        id={"#{@id}_input"}
        class={"
            text-2xl
            text-gray-500
            bold
            bg-transparent
            group-hover:bg-white
            dark:group-hover:bg-gray-800
            py-1
            w-12
            text-center
            group-hover:mx-0
            focus:mx-0
            cursor-text
            #{if @show_navigation_arrows, do: "mx-8", else: ""}"
          }
        onfocus={"handleInputFocus_#{@id}()"}
        onblur={"handleInputFocus_#{@id}(false)"}
        name="page_number"
        autocomplete="off"
        value={@page_number}
      />
      <input hidden name="preview_mode" value={"#{@preview_mode}"} />
      <input hidden type="submit" />
      <p
        id={"#{@id}_popover"}
        class="absolute right-1/2 translate-x-1/2 p-2 -bottom-20 mb-0 hidden bg-delivery-primary/80 text-white w-56 h-16 text-center whitespace-normal"
      >
        Enter a page between {@min_page} and {@max_page} and press enter
      </p>
      <%= if @show_navigation_arrows and @next_page do %>
        <a
          href={PageDeliveryView.next_url(OliWeb.Endpoint, @next_page, @preview_mode, @section_slug)}
          class="!no-underline rounded-r w-8 py-1 hidden group-hover:flex text-center cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-600"
        >
          <i class="fa-solid fa-chevron-right text-delivery-primary self-center mx-auto"></i>
        </a>
      <% end %>
    </.form>
    """
  end
end
