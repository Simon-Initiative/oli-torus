defmodule OliWeb.Components.Common do
  use Phoenix.Component

  use Gettext, backend: OliWeb.Gettext

  alias OliWeb.Common.{FormatDateTime, React}
  alias Phoenix.LiveView.JS

  def not_found(assigns) do
    ~H"""
    <main role="main" class="container mx-auto">
      <div class="alert alert-danger mt-3" role="alert">
        <h4 class="alert-heading">Not Found</h4>
        <p>
          The page you are trying to access does not exist. If you think this is an error, please contact support.
        </p>
        <hr />
        <p class="mb-0"><b>Tip:</b> Check the URL or link and try again.</p>
      </div>
    </main>
    """
  end

  @doc """
  Badge component
  """
  attr(:variant, :atom, default: nil, values: [:primary, :info, :success, :warning, :danger, nil])
  attr(:class, :string, default: nil)
  slot(:inner_block, required: true)

  def badge(assigns) do
    ~H"""
    <span class={[
      "text-xs font-medium mr-2 px-2.5 py-0.5 rounded-xl border uppercase",
      badge_variant_classes(@variant),
      @class
    ]}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  defp badge_variant_classes(variant) do
    case variant do
      :primary -> "text-white bg-blue-500 border-blue-500"
      :info -> "text-white bg-gray-500 border-gray-500"
      :success -> "text-white bg-green-500 border-green-500"
      :warning -> "text-white bg-yellow-500 border-yellow-500"
      :danger -> "text-white bg-red-500 border-red-500"
      _ -> ""
    end
  end

  defp button_variant_classes(variant, disabled: true) do
    case variant do
      :primary ->
        "rounded text-white bg-primary-200 dark:bg-primary-900 cursor-not-allowed hover:no-underline"

      :secondary ->
        "rounded text-gray-500 bg-transparent dark:text-gray-500 cursor-not-allowed hover:no-underline"

      :tertiary ->
        "rounded text-primary-300 bg-primary-50 dark:text-primary-500 dark:bg-primary-800 cursor-not-allowed hover:no-underline"

      :light ->
        "rounded text-gray-400 bg-gray-50 dark:text-gray-500 dark:bg-gray-900 cursor-not-allowed hover:no-underline"

      :dark ->
        "rounded text-gray-400 bg-gray-500 dark:text-gray-300 dark:bg-gray-800 cursor-not-allowed hover:no-underline"

      :info ->
        "rounded text-gray-100 bg-gray-300 dark:bg-gray-800 cursor-not-allowed hover:no-underline"

      :success ->
        "rounded text-green-100 bg-green-300 dark:bg-green-600 cursor-not-allowed hover:no-underline"

      :warning ->
        "rounded text-yellow-100 bg-yellow-300 dark:bg-yellow-600 cursor-not-allowed hover:no-underline"

      :danger ->
        "rounded text-red-100 bg-red-300 dark:bg-red-600 cursor-not-allowed hover:no-underline"

      :link ->
        "rounded text-blue-400 dark:text-blue-800 cursor-default"

      :link_info ->
        "rounded text-gray-400 dark:text-gray-800 cursor-default"

      :link_success ->
        "rounded text-green-400 dark:text-green-800 cursor-default"

      :link_warning ->
        "rounded text-yellow-400 dark:text-yellow-800 cursor-default"

      :link_danger ->
        "rounded text-red-400 dark:text-red-800 cursor-default"

      _ ->
        ""
    end
  end

  defp button_variant_classes(variant, _) do
    case variant do
      :primary ->
        "rounded text-white hover:text-white bg-primary-500 hover:bg-primary-600 active:bg-primary-700 focus:ring-2 focus:ring-primary-400 dark:bg-primary-600 dark:hover:bg-primary dark:active:bg-primary-400 focus:outline-none dark:focus:ring-primary-700 hover:no-underline"

      :secondary ->
        "rounded text-body-color hover:text-body-color bg-transparent hover:bg-gray-200 active:text-white active:bg-primary-700 focus:ring-2 focus:ring-primary-400 dark:text-body-color-dark dark:hover:bg-gray-600 dark:active:bg-primary-400 focus:outline-none dark:focus:ring-primary-700 hover:no-underline"

      :tertiary ->
        "rounded text-primary-700 hover:text-primary-700 bg-primary-50 hover:bg-primary-100 active:bg-primary-200 focus:ring-2 focus:ring-primary-100 dark:text-primary-300 dark:bg-primary-800 dark:hover:bg-primary-700 dark:active:bg-primary-600 focus:outline-none dark:focus:ring-primary-800 hover:no-underline"

      :outline ->
        "rounded text-body-color hover:text-body-color bg-transparent border border-body-color dark:border-body-color-dark hover:bg-gray-200 active:text-white active:bg-primary-700 focus:ring-2 focus:ring-primary-400 dark:text-body-color-dark dark:hover:bg-gray-600 dark:active:bg-primary-400 dark:focus:ring-primary-700 hover:no-underline"

      :light ->
        "rounded text-body-color hover:text-body-color bg-gray-100 hover:bg-gray-200 active:bg-gray-300 focus:ring-2 focus:ring-gray-100 dark:text-white dark:bg-gray-800 dark:hover:bg-gray-700 dark:active:bg-gray-600 focus:outline-none dark:focus:ring-gray-800 hover:no-underline"

      :dark ->
        "rounded text-white hover:text-white bg-gray-700 hover:bg-gray-800 active:bg-gray-600 focus:ring-2 focus:ring-gray-600 dark:text-white dark:bg-gray-700 dark:hover:bg-gray-600 dark:active:bg-gray-500 focus:outline-none dark:focus:ring-gray-500 hover:no-underline"

      :info ->
        "rounded text-white hover:text-white bg-gray-500 hover:bg-gray-600 active:bg-gray-700 focus:ring-2 focus:ring-gray-400 dark:bg-gray-600 dark:hover:bg-gray-500 dark:active:bg-gray-400 focus:outline-none dark:focus:ring-gray-700 hover:no-underline"

      :success ->
        "rounded text-white hover:text-white bg-green-600 hover:bg-green-700 active:bg-green-800 focus:ring-2 focus:ring-green-700 dark:bg-green-600 dark:hover:bg-green-500 dark:active:bg-green-400 focus:outline-none dark:focus:ring-green-700 hover:no-underline"

      :warning ->
        "rounded text-white hover:text-white bg-yellow-500 hover:bg-yellow-600 active:bg-yellow-700 focus:ring-2 focus:ring-yellow-400 dark:bg-yellow-600 dark:hover:bg-yellow-500 dark:active:bg-yellow-400 focus:outline-none dark:focus:ring-yellow-700 hover:no-underline"

      :danger ->
        "rounded text-white hover:text-white bg-red-500 hover:bg-red-600 active:bg-red-700 focus:ring-2 focus:ring-red-400 dark:bg-red-600 dark:hover:bg-red-500 dark:active:bg-red-400 focus:outline-none dark:focus:ring-red-700 hover:no-underline"

      :link ->
        "rounded text-blue-500 hover:text-blue-600 hover:text-blue-600 active:text-blue-700 focus:ring-2 focus:ring-blue-400 dark:text-blue-600 dark:hover:text-blue-500 dark:active:text-blue-400 focus:outline-none dark:focus:ring-blue-700 hover:underline cursor-pointer"

      :link_info ->
        "rounded text-gray-500 hover:text-gray-600 active:text-gray-700 focus:ring-2 focus:ring-gray-400 dark:text-gray-600 dark:hover:text-gray-500 dark:active:text-gray-400 focus:outline-none dark:focus:ring-gray-700 hover:underline cursor-pointer"

      :link_success ->
        "rounded text-green-500 hover:text-green-600 active:text-green-700 focus:ring-2 focus:ring-green-400 dark:text-green-600 dark:hover:text-green-500 dark:active:text-green-400 focus:outline-none dark:focus:ring-green-700 hover:underline cursor-pointer"

      :link_warning ->
        "rounded text-yellow-500 hover:text-yellow-600 active:text-yellow-700 focus:ring-2 focus:ring-yellow-400 dark:text-yellow-600 dark:hover:text-yellow-500 dark:active:text-yellow-400 focus:outline-none dark:focus:ring-yellow-700 hover:underline cursor-pointer"

      :link_danger ->
        "rounded text-red-500 hover:text-red-600 active:text-red-700 focus:ring-2 focus:ring-red-400 dark:text-red-600 dark:hover:text-red-500 dark:active:text-red-400 focus:outline-none dark:focus:ring-red-700 hover:underline cursor-pointer"

      _ ->
        ""
    end
  end

  defp button_size_classes(size) do
    case size do
      :xs -> "text-xs px-3 py-1"
      :sm -> "text-sm px-4 py-1.5"
      :md -> "text-base px-6 py-2"
      :lg -> "text-lg px-7 py-2"
      :xl -> "text-xl px-8 py-2"
      _ -> ""
    end
  end

  @doc """
  Button component.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
      <.button href={~p"/some/route"} class="ml-2">Go!</.button>
  """
  attr(:variant, :atom,
    default: nil,
    values: [
      :primary,
      :secondary,
      :tertiary,
      :outline,
      :light,
      :dark,
      :info,
      :success,
      :warning,
      :danger,
      :link,
      :link_info,
      :link_success,
      :link_warning,
      :link_danger,
      nil
    ]
  )

  attr(:size, :atom, default: :md, values: [:xs, :sm, :md, :lg, :xl, :custom, nil])
  attr(:href, :string, default: nil)
  attr(:type, :string, default: nil)
  attr(:class, :string, default: nil)

  attr(:rest, :global,
    include: ~w(disabled form name value target rel method download xphx-mouseover)
  )

  slot(:inner_block, required: true)

  def button(assigns) do
    ~H"""
    <%= case @href do %>
      <% nil -> %>
        <button
          type={@type}
          class={[
            "text-center whitespace-nowrap overflow-hidden text-ellipsis",
            button_variant_classes(@variant, disabled: @rest[:disabled]),
            button_size_classes(@size),
            @class
          ]}
          {@rest}
        >
          <%= render_slot(@inner_block) %>
        </button>
      <% _ -> %>
        <a
          href={@href}
          class={[
            "text-center whitespace-nowrap overflow-hidden text-ellipsis",
            button_variant_classes(@variant, disabled: @rest[:disabled]),
            button_size_classes(@size),
            @class
          ]}
          {@rest}
        >
          <%= render_slot(@inner_block) %>
        </a>
    <% end %>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr(:id, :any, default: nil)
  attr(:name, :any)
  attr(:label, :string, default: nil)
  attr(:value, :any)

  attr(:field_value, :any,
    doc:
      "in case of radio input, this stores the value of the field and not the value of the input"
  )

  attr(:type, :string,
    default: "text",
    values:
      ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week custom_radio custom_checkbox)
  )

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"
  )

  attr(:variant, :string, default: "standard", values: ~w(outlined standard))

  attr(:errors, :list, default: [])
  attr(:class, :string, default: nil)

  attr(:label_class, :string, default: "")
  attr(:checked, :boolean, doc: "the checked flag for checkbox inputs")
  attr(:ctx, :map, default: nil)
  attr(:prompt, :string, default: nil, doc: "the prompt for select inputs")
  attr(:options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2")
  attr(:multiple, :boolean, default: false, doc: "the multiple flag for select inputs")

  attr(:rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)
  )

  attr(:label_position, :atom, default: :top, values: [:top, :bottom, :responsive])
  attr(:error_position, :atom, default: :bottom, values: [:top, :bottom])
  attr(:additional_text, :string, default: nil)
  attr(:group_class, :string, default: "contents")

  slot(:inner_block)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id, field_value: field.value)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> assign_new(:class, fn -> assigns[:class] end)
    |> input()
  end

  def input(%{type: "checkbox", value: value} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn -> Phoenix.HTML.Form.normalize_value("checkbox", value) end)

    ~H"""
    <div class="contents" phx-feedback-for={@name}>
      <label class={"flex gap-2 items-center #{@label_class}"}>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={@class}
          {@rest}
        />
        <%= @label %>
      </label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    assigns = assigns |> set_input_classes() |> set_input_placeholder()

    ~H"""
    <div class={@group_class} phx-feedback-for={@name}>
      <.label :if={@label && @label_position == :top} class={@label_class} for={@id}>
        <%= @label %>
      </.label>
      <select id={@id} name={@name} class={@input_class} multiple={@multiple} {@rest}>
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.label
        :if={@label && (@label_position == :bottom || @label_position == :responsive)}
        class={@label_class}
        for={@id}
      >
        <%= @label %>
      </.label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class={@group_class} phx-feedback-for={@name}>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <%= if @additional_text do %>
        <%= @additional_text %>
      <% end %>
      <textarea
        id={@id}
        name={@name}
        class={[
          @class,
          @errors != [] && "border-red-400 focus:border-red-400"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "datetime-local"} = assigns) do
    assigns =
      if assigns[:ctx] do
        assign(assigns,
          value: FormatDateTime.convert_datetime(assigns.value, assigns.ctx)
        )
      else
        assigns
      end

    ~H"""
    <div class="contents" phx-feedback-for={@name}>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          @class,
          @errors != [] && "border-red-400 focus:border-red-400"
        ]}
        {Map.delete(@rest, :ctx)}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "custom_radio", field_value: field_value, value: value} = assigns) do
    assigns =
      assign(assigns,
        id: "#{value}_radio_button",
        is_checked: is_radio_checked?(field_value, value)
      )

    ~H"""
    <label
      name={@name}
      phx-click={
        JS.set_attribute({"data-checked", false}, to: "label[name=\"#{@name}\"]")
        |> JS.set_attribute({"data-checked", true})
      }
      class={[
        "p-2 rounded border border-primary cursor-pointer",
        "data-[checked=true]:bg-primary data-[checked=true]:hover:bg-delivery-primary-600 data-[checked=true]:text-white",
        "data-[checked=false]:bg-white data-[checked=false]:dark:bg-gray-800 data-[checked=false]:hover:bg-delivery-primary-100 data-[checked=false]:text-primary"
      ]}
      data-checked={"#{@is_checked}"}
      for={@id}
    >
      <span><%= @label %></span>
      <input
        type="radio"
        name={@name}
        id={@id}
        value={@value}
        class="hidden"
        {Map.delete(@rest, :ctx)}
      />
    </label>
    """
  end

  def input(%{type: "custom_checkbox", field_value: field_value, value: value} = assigns) do
    assigns =
      assign(assigns,
        id: "#{value}_radio_button",
        is_checked: is_radio_checked?(field_value, value)
      )

    ~H"""
    <label
      onclick={"
        (() => {
          checked = this.dataset['checked'] == 'true' ? false : true;
          this.dataset['checked'] = checked;
          document.getElementById('#{@id}').checked = checked;
        })();
      "}
      data-checked={"#{@is_checked}"}
      class={[
        "h-10 w-10 text-xs text-primary font-semibold cursor-pointer p-3 aspect-square !flex items-center justify-center rounded-full border border-primary",
        "data-[checked=true]:bg-primary data-[checked=true]:hover:bg-delivery-primary-600 data-[checked=true]:text-white",
        "data-[checked=false]:bg-white data-[checked=false]:dark:bg-gray-800 data-[checked=false]:hover:bg-delivery-primary-100 data-[checked=false]:text-primary"
      ]}
      for={"##{@id}"}
    >
      <input
        type="checkbox"
        name={@name}
        id={@id}
        value={@value}
        checked={@is_checked}
        class="hidden"
      />
      <span><%= @label %></span>
    </label>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    assigns = assigns |> set_input_classes() |> set_input_placeholder()

    ~H"""
    <div class={@group_class} phx-feedback-for={@name}>
      <.label :if={@label && @label_position == :top} class={@label_class} for={@id}>
        <%= @label %>
        <%= if @additional_text do %>
          <%= @additional_text %>
        <% end %>
      </.label>
      <.error :for={msg <- @errors} :if={@error_position == :top}><%= msg %></.error>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={@input_class}
        placeholder={@placeholder}
        {@rest}
      />
      <.label
        :if={@label && (@label_position == :bottom || @label_position == :responsive)}
        class={@label_class}
        for={@id}
      >
        <%= @label %>
        <%= if @additional_text do %>
          <%= @additional_text %>
        <% end %>
      </.label>
      <.error :for={msg <- @errors} :if={@error_position == :bottom}><%= msg %></.error>
    </div>
    """
  end

  defp set_input_placeholder(assigns) do
    placeholder =
      if assigns[:variant] == "outlined" do
        assigns[:placeholder] || assigns[:label]
      else
        assigns[:placeholder]
      end

    assign(assigns, placeholder: placeholder)
  end

  defp set_input_classes(assigns) do
    input_class = [
      assigns.class,
      assigns.errors != [] && "border-red-400 focus:border-red-400",
      assigns.rest[:readonly] && "bg-gray-200 dark:bg-gray-600"
    ]

    {group_class, label_class, input_class} =
      if assigns[:variant] == "outlined" do
        {"form-label-group", "control-label pointer-events-none", ["form-control" | input_class]}
      else
        {"flex flex-col", assigns.label_class || "", input_class}
      end

    assign(assigns, group_class: group_class, label_class: label_class, input_class: input_class)
  end

  defp is_radio_checked?(field_value, value) when is_list(field_value) do
    Enum.member?(field_value, value)
  end

  defp is_radio_checked?(field_value, value) do
    case {is_atom(field_value), is_atom(value)} do
      {false, true} -> String.to_atom(field_value) == value
      {true, false} -> field_value == String.to_atom(value)
      field_value -> field_value == value
    end
  end

  @doc """
  Generates a generic error message.
  """
  slot(:inner_block, required: true)
  attr(:for, :string, default: nil)

  def error(assigns) do
    ~H"""
    <p
      class="flex gap-3 text-sm leading-6 text-rose-600 phx-no-feedback:hidden"
      phx-feedback-for={@for}
    >
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders a label.
  """
  attr(:for, :string, default: nil)
  attr(:if, :boolean, default: true)
  attr(:class, :string, default: nil)
  attr(:onclick, :string, default: nil)
  slot(:inner_block, required: true)

  def label(assigns) do
    ~H"""
    <label :if={@if} for={@for} class={@class} onclick={@onclick}>
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  def fetch_field(f, field) do
    case Ecto.Changeset.fetch_field(f, field) do
      {_, value} -> value
      _ -> nil
    end
  end

  attr(:class, :string, default: nil)
  attr(:icon_class, :string, default: nil)

  def loader(assigns) do
    ~H"""
    <div class={@class || "flex items-center justify-center"}>
      <span
        class={["spinner-border spinner-border-sm text-primary", @icon_class]}
        role="status"
        aria-hidden="true"
      />
    </div>
    """
  end

  attr(:percent, :integer, required: true)
  attr(:width, :string, default: "100%")
  attr(:show_percent, :boolean, default: true)

  attr(:show_halo, :boolean,
    default: false,
    doc: "shows a blurry halo at the end of the progress bar"
  )

  attr(:role, :string, default: "progress_bar")
  attr(:height, :string, default: "h-1")
  attr(:rounded, :string, default: "rounded-[60px]")

  attr(:on_going_colour, :string,
    default: "bg-[#1E9531]",
    doc: "the colour of the progress bar when progress < 100%"
  )

  attr(:completed_colour, :string,
    default: "bg-[#1E9531]",
    doc: "the colour of the progress bar when progress = 100%"
  )

  attr(:not_completed_colour, :string,
    default: "bg-gray-600/20 dark:bg-white/20",
    doc: "the colour of the not completed section of the progress bar"
  )

  def progress_bar(assigns) do
    ~H"""
    <div class="flex flex-row items-center gap-3 mx-auto w-full" role={@role}>
      <div class="flex justify-center w-full relative">
        <div class={"#{@rounded} #{@height} #{@not_completed_colour}"} style={"width: #{@width}"}>
          <div
            role="progress"
            class={[
              "#{@rounded} #{@height}",
              if(@percent == 100, do: @completed_colour, else: @on_going_colour)
            ]}
            style={"width: #{if @percent == 0, do: 1, else: @percent}%"}
          >
          </div>
        </div>

        <div
          :if={@show_halo}
          role="halo"
          class="absolute -top-[5px] z-50 w-6 h-3.5 bg-[#39e581]/40 rounded-[47px] blur-[8px]"
          style={"left: #{@percent}%; transform: translateX(-12px);"}
        >
        </div>
      </div>
      <div
        :if={@show_percent}
        class="text-right dark:text-white text-base font-semibold leading-loose tracking-tight"
      >
        <%= if @percent == 100 do %>
          <div class="flex gap-1 ml-2">
            Completed
            <div class="w-7 h-8 py-1 flex gap-2.5">
              <OliWeb.Icons.check />
            </div>
          </div>
        <% else %>
          <%= @percent %>%
        <% end %>
      </div>
    </div>
    """
  end

  attr(:role, :string)
  attr(:id, :string)
  attr(:button_class, :string)
  attr(:options, :list)
  attr(:rest, :global, include: ~w(disabled class))
  slot(:inner_block)

  def dropdown(assigns) do
    ~H"""
    <div class={["relative", @rest[:class]]} phx-click-away={JS.hide(to: "##{@id}-options")}>
      <button
        phx-click={
          JS.toggle(
            to: "##{@id}-options",
            in: {"ease-out duration-300", "opacity-0", "opacity-100"},
            out: {"ease-out duration-200", "opacity-100", "opacity-0"}
          )
        }
        id={@id}
        role={@role}
        class={[@button_class]}
      >
        <%= render_slot(@inner_block) %>
      </button>
      <ul
        class="hidden absolute top-10 rounded-lg bg-white dark:bg-gray-800 dark:border dark:border-gray-900 p-4 z-10 shadow-lg"
        id={"#{@id}-options"}
        class="hidden"
      >
        <%= for option <- @options do %>
          <li>
            <button
              phx-click={option.on_click |> JS.hide(to: "##{@id}-options")}
              class={[
                "flex items-center w-full gap-[10px] px-[10px] py-[4px] hover:text-gray-400 dark:text-white dark:hover:text-white/50",
                option[:class]
              ]}
              role={"dropdown-item #{option.text}"}
            >
              <span class="text-[14px] leading-[20px] whitespace-nowrap"><%= option.text %></span>
              <%= Phoenix.HTML.raw(option[:icon]) %>
            </button>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  @doc """
  Renders a [Fontawesome 6](https://fontawesome.com/icons) icon.

  ## Examples

      <.icon name="fa-solid fa-xmark" />
      <.icon name="fa-solid fa-xmark" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr(:name, :string, required: true)
  attr(:class, :string, default: nil)

  def icon(assigns) do
    ~H"""
    <i class={[@name, @class]} />
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr(:id, :string, default: "flash", doc: "the optional id of flash container")
  attr(:flash, :map, default: %{}, doc: "the map of flash messages to display")
  attr(:title, :string, default: nil)
  attr(:kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup")
  attr(:rest, :global, doc: "the arbitrary HTML attributes to add to the flash container")

  slot(:inner_block, doc: "the optional inner block that renders the flash message")

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      class={[
        "mb-4 rounded-lg px-5 py-3 text-base text-primary-600",
        @kind == :info && "bg-primary-100 text-primary-600",
        @kind == :error && "bg-red-100 text-red-700"
      ]}
      role="alert"
      {@rest}
    >
      <div class="flex flex-row">
        <div class="flex-1">
          <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
            <.icon :if={@kind == :info} name="fa-solid fa-circle-info" class="h-4 w-4" />
            <.icon :if={@kind == :error} name="fa-solid fa-circle-exclamation" class="h-4 w-4" />
            <%= @title %>
          </p>
          <p class="mt-2 text-sm leading-5"><%= msg %></p>
        </div>
        <div>
          <button
            type="button"
            class="group"
            aria-label={gettext("close")}
            phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
          >
            <.icon name="fa-solid fa-xmark" class="w-5 h-5 opacity-40 group-hover:opacity-70" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} title="Success!" flash={@flash} />
    <.flash kind={:error} title="Error!" flash={@flash} />
    <.flash
      id="client-error"
      kind={:error}
      title="We can't find the internet"
      phx-disconnected={show(".phx-client-error #client-error")}
      phx-connected={hide("#client-error")}
      hidden
    >
      Attempting to reconnect <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
    </.flash>

    <.flash
      id="server-error"
      kind={:error}
      title="Something went wrong!"
      phx-disconnected={show(".phx-server-error #server-error")}
      phx-connected={hide("#server-error")}
      hidden
    >
      Hang in there while we get back on track
      <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
    </.flash>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(OliWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(OliWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Renders a hero banner.
  """
  attr(:class, :string, default: nil)
  slot(:inner_block, required: true)

  def hero_banner(assigns) do
    ~H"""
    <div class={["w-full bg-cover bg-center bg-no-repeat py-12 md:py-24 px-8 md:px-16", @class]}>
      <div class="container mx-auto flex flex-col">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a loading spinner.
  """
  attr(:size_px, :integer, default: 64)

  def loading_spinner(assigns) do
    ~H"""
    <svg
      class="loading"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      style="margin: auto; background: none; display: block; shape-rendering: auto;"
      width={"#{@size_px}px"}
      height={"#{@size_px}px"}
      viewBox={"#{Kernel.div(@size_px, 4)} #{Kernel.div(@size_px, 4)} #{@size_px} #{@size_px}"}
      preserveAspectRatio="xMidYMid"
    >
      <g transform="rotate(0 50 50)">
        <rect x="48.5" y="34" rx="1.28" ry="1.28" width="3" height="8" fill="#757575">
          <animate
            attributeName="opacity"
            values="1;0"
            keyTimes="0;1"
            dur="1s"
            begin="-0.9090909090909091s"
            repeatCount="indefinite"
          >
          </animate>
        </rect>
      </g>
      <g transform="rotate(32.72727272727273 50 50)">
        <rect x="48.5" y="34" rx="1.28" ry="1.28" width="3" height="8" fill="#757575">
          <animate
            attributeName="opacity"
            values="1;0"
            keyTimes="0;1"
            dur="1s"
            begin="-0.8181818181818182s"
            repeatCount="indefinite"
          >
          </animate>
        </rect>
      </g>
      <g transform="rotate(65.45454545454545 50 50)">
        <rect x="48.5" y="34" rx="1.28" ry="1.28" width="3" height="8" fill="#757575">
          <animate
            attributeName="opacity"
            values="1;0"
            keyTimes="0;1"
            dur="1s"
            begin="-0.7272727272727273s"
            repeatCount="indefinite"
          >
          </animate>
        </rect>
      </g>
      <g transform="rotate(98.18181818181819 50 50)">
        <rect x="48.5" y="34" rx="1.28" ry="1.28" width="3" height="8" fill="#757575">
          <animate
            attributeName="opacity"
            values="1;0"
            keyTimes="0;1"
            dur="1s"
            begin="-0.6363636363636364s"
            repeatCount="indefinite"
          >
          </animate>
        </rect>
      </g>
      <g transform="rotate(130.9090909090909 50 50)">
        <rect x="48.5" y="34" rx="1.28" ry="1.28" width="3" height="8" fill="#757575">
          <animate
            attributeName="opacity"
            values="1;0"
            keyTimes="0;1"
            dur="1s"
            begin="-0.5454545454545454s"
            repeatCount="indefinite"
          >
          </animate>
        </rect>
      </g>
      <g transform="rotate(163.63636363636363 50 50)">
        <rect x="48.5" y="34" rx="1.28" ry="1.28" width="3" height="8" fill="#757575">
          <animate
            attributeName="opacity"
            values="1;0"
            keyTimes="0;1"
            dur="1s"
            begin="-0.45454545454545453s"
            repeatCount="indefinite"
          >
          </animate>
        </rect>
      </g>
      <g transform="rotate(196.36363636363637 50 50)">
        <rect x="48.5" y="34" rx="1.28" ry="1.28" width="3" height="8" fill="#757575">
          <animate
            attributeName="opacity"
            values="1;0"
            keyTimes="0;1"
            dur="1s"
            begin="-0.36363636363636365s"
            repeatCount="indefinite"
          >
          </animate>
        </rect>
      </g>
      <g transform="rotate(229.0909090909091 50 50)">
        <rect x="48.5" y="34" rx="1.28" ry="1.28" width="3" height="8" fill="#757575">
          <animate
            attributeName="opacity"
            values="1;0"
            keyTimes="0;1"
            dur="1s"
            begin="-0.2727272727272727s"
            repeatCount="indefinite"
          >
          </animate>
        </rect>
      </g>
      <g transform="rotate(261.8181818181818 50 50)">
        <rect x="48.5" y="34" rx="1.28" ry="1.28" width="3" height="8" fill="#757575">
          <animate
            attributeName="opacity"
            values="1;0"
            keyTimes="0;1"
            dur="1s"
            begin="-0.18181818181818182s"
            repeatCount="indefinite"
          >
          </animate>
        </rect>
      </g>
      <g transform="rotate(294.54545454545456 50 50)">
        <rect x="48.5" y="34" rx="1.28" ry="1.28" width="3" height="8" fill="#757575">
          <animate
            attributeName="opacity"
            values="1;0"
            keyTimes="0;1"
            dur="1s"
            begin="-0.09090909090909091s"
            repeatCount="indefinite"
          >
          </animate>
        </rect>
      </g>
      <g transform="rotate(327.27272727272725 50 50)">
        <rect x="48.5" y="34" rx="1.28" ry="1.28" width="3" height="8" fill="#757575">
          <animate
            attributeName="opacity"
            values="1;0"
            keyTimes="0;1"
            dur="1s"
            begin="0s"
            repeatCount="indefinite"
          >
          </animate>
        </rect>
      </g>
    </svg>
    """
  end

  @doc """
  Wraps tab focus around a container for accessibility.

  This is an essential accessibility feature for interfaces such as modals, dialogs, and menus.

  It differs from the native focus_wrap as it does not autofocus the first element in the container
  on mount.

  ## Examples

  Simply render your inner content within this component and focus will be wrapped around the
  container as the user tabs through the containers content:

  ```heex
  <.custom_focus_wrap id="my-modal" class="bg-white">
    <div id="modal-content">
      Are you sure?
      <button phx-click="cancel">Cancel</button>
      <button phx-click="confirm">OK</button>
    </div>
  </.custom_focus_wrap>
  ```
  """
  attr(:id, :string, required: true, doc: "The DOM identifier of the container tag.")

  attr(:rest, :global, doc: "Additional HTML attributes to add to the container tag.")

  attr(:initially_enabled, :boolean,
    default: true,
    doc: "Whether the focus wrap is initially enabled."
  )

  slot(:inner_block, required: true, doc: "The content rendered inside of the container tag.")

  def custom_focus_wrap(assigns) do
    ~H"""
    <div id={@id} phx-hook="CustomFocusWrap" {@rest}>
      <span
        id={"#{@id}-start"}
        tabindex={if @initially_enabled, do: "0", else: "-1"}
        aria-hidden="true"
      >
      </span>
      <%= render_slot(@inner_block) %>
      <span id={"#{@id}-end"} tabindex="-1" aria-hidden="true"></span>
    </div>
    """
  end

  attr :on_toggle, :string, required: true
  attr :label, :string, default: nil
  attr :name, :string, default: nil
  attr :checked, :boolean, default: false
  attr :phx_target, :any, default: nil
  attr :with_confirmation, :boolean, default: false
  attr :rest, :global, include: ~w(class disabled role)

  def toggle_switch(assigns) do
    ~H"""
    <div {@rest}>
      <form id="toggle_switch_form" phx-change={@on_toggle} phx-target={@phx_target}>
        <label class="inline-flex items-center cursor-pointer">
          <input
            id="toggle_switch_checkbox"
            type="checkbox"
            name={@name}
            class="sr-only peer"
            checked={@checked}
            phx-hook={if @with_confirmation, do: "ConditionalToggle"}
            data-checked={"#{@checked}"}
          />
          <div class="relative w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4
                      peer-focus:ring-primary-300 dark:peer-focus:ring-primary-800 rounded-full
                      peer dark:bg-gray-700 peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full
                      peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px]
                      after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5
                      after:w-5 after:transition-transform dark:border-gray-600 peer-checked:bg-primary
                      after:duration-300 after:ease-in-out transition-colors duration-300 ease-in-out">
          </div>
          <%= case @label do %>
            <% nil -> %>
            <% label -> %>
              <span class="ms-3 text-sm"><%= label %></span>
          <% end %>
        </label>
      </form>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :form, :any, required: true
  attr :value, :any, required: true
  attr :field_name, :atom, required: true
  attr :field_label, :string, required: true
  attr :on_edit, :string, required: true
  attr :project_slug, :string, required: true
  attr :ctx, :map, required: true

  def rich_text_editor_field(assigns) do
    ~H"""
    <div id={@id} class="form-label-group mb-3">
      <.input
        field={@form[@field_name]}
        label={@field_label}
        type="hidden"
        label_class="control-label"
        error_position={:top}
        errors={@form.errors}
      />

      <div id="rich_text_editor" phx-update="ignore">
        <%= React.component(
          @ctx,
          "Components.RichTextEditor",
          %{
            projectSlug: @project_slug,
            onEdit: "initial_function_that_will_be_overwritten",
            onEditEvent: @on_edit,
            onEditTarget: "##{@id}",
            editMode: true,
            value: @value,
            fixedToolbar: true,
            allowBlockElements: false
          },
          id: "rich_text_editor_react_component"
        ) %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a simple form box.

  ## Examples

      <.form_box for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.form_box>
  """
  attr :for, :any, required: true, doc: "the data structure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :class, :string, default: nil, doc: "the class to apply to the form"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :title, default: nil, doc: "the title of the form"
  slot :subtitle, default: nil, doc: "the subtitle of the form"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def form_box(assigns) do
    ~H"""
    <div class={["w-96 dark:bg-neutral-700 sm:rounded-md sm:shadow-lg dark:text-white py-8 px-10"]}>
      <div :if={@title} class="text-center text-xl font-normal leading-7 pb-6">
        <%= render_slot(@title) %>
      </div>
      <div :if={@subtitle} class="text-center leading-6 pb-6">
        <%= render_slot(@subtitle) %>
      </div>

      <.form :let={f} for={@for} as={@as} {@rest}>
        <%= render_slot(@inner_block, f) %>

        <div :for={action <- @actions} class="mt-2 flex flex-col items-center justify-between gap-2">
          <%= render_slot(action, f) %>
        </div>
      </.form>
    </div>
    """
  end

  attr :recaptcha_error, :string, required: true
  attr :class, :string, default: "w-80 mx-auto"

  def render_recaptcha(assigns) do
    ~H"""
    <div class={@class}>
      <div
        id="recaptcha"
        phx-hook="Recaptcha"
        data-sitekey={Application.fetch_env!(:oli, :recaptcha)[:site_key]}
        data-theme="light"
        phx-update="ignore"
      >
      </div>
      <.error :if={@recaptcha_error}><%= @recaptcha_error %></.error>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :class, :string, default: ""
  attr :show_text, :boolean, default: true

  def tech_support_button(assigns) do
    ~H"""
    <button
      id={@id}
      phx-click={JS.dispatch("click", to: "#trigger-tech-support-modal")}
      class={[
        "w-auto mr-auto h-11 px-3 py-3 flex-col justify-center items-start inline-flex text-black/70 hover:text-black/90 dark:text-gray-400 hover:dark:text-white stroke-black/70 hover:stroke-black/90 dark:stroke-[#B8B4BF] hover:dark:stroke-white",
        @class
      ]}
    >
      <div class="justify-start items-end gap-3 inline-flex">
        <div class="w-5 h-5 flex items-center justify-center">
          <OliWeb.Icons.support class="" />
        </div>
        <div :if={@show_text} class="text-sm font-medium tracking-tight">
          Support
        </div>
      </div>
    </button>
    """
  end

  attr :id, :string, required: true
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def tech_support_link(assigns) do
    ~H"""
    <span id={@id} phx-click={JS.dispatch("click", to: "#trigger-tech-support-modal")} class={@class}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end
end
