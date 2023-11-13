defmodule OliWeb.Components.Common do
  use Phoenix.Component

  alias OliWeb.Common.FormatDateTime
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
      "text-xs font-medium mr-2 px-2.5 py-0.5 rounded border uppercase",
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
        "rounded text-white bg-primary-200 dark:bg-primary-900 cursor-not-allowed"

      :secondary ->
        "rounded text-gray-500 bg-transparent dark:text-gray-500 cursor-not-allowed"

      :tertiary ->
        "rounded text-primary-300 bg-primary-50 dark:text-primary-500 dark:bg-primary-800 cursor-not-allowed"

      :light ->
        "rounded text-gray-400 bg-gray-50 dark:text-gray-500 dark:bg-gray-900 cursor-not-allowed"

      :dark ->
        "rounded text-gray-400 bg-gray-500 dark:text-gray-300 dark:bg-gray-800 cursor-not-allowed"

      :info ->
        "rounded text-gray-100 bg-gray-300 dark:bg-gray-800 cursor-not-allowed"

      :success ->
        "rounded text-green-100 bg-green-300 dark:bg-green-600 cursor-not-allowed"

      :warning ->
        "rounded text-yellow-100 bg-yellow-300 dark:bg-yellow-600 cursor-not-allowed"

      :danger ->
        "rounded text-red-100 bg-red-300 dark:bg-red-600 cursor-not-allowed"

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
        "rounded text-white hover:text-white bg-primary-500 hover:bg-primary-600 active:bg-primary-700 focus:ring-2 focus:ring-primary-400 dark:bg-primary-600 dark:hover:bg-primary dark:active:bg-primary-400 focus:outline-none dark:focus:ring-primary-700"

      :secondary ->
        "rounded text-body-color bg-transparent hover:bg-gray-200 active:text-white active:bg-primary-700 focus:ring-2 focus:ring-primary-400 dark:text-body-color-dark dark:hover:bg-gray-600 dark:active:bg-primary-400 focus:outline-none dark:focus:ring-primary-700"

      :tertiary ->
        "rounded text-primary-700 bg-primary-50 hover:bg-primary-100 active:bg-primary-200 focus:ring-2 focus:ring-primary-100 dark:text-primary-300 dark:bg-primary-800 dark:hover:bg-primary-700 dark:active:bg-primary-600 focus:outline-none dark:focus:ring-primary-800"

      :light ->
        "rounded text-body-color bg-gray-100 hover:bg-gray-200 active:bg-gray-300 focus:ring-2 focus:ring-gray-100 dark:text-white dark:bg-gray-800 dark:hover:bg-gray-700 dark:active:bg-gray-600 focus:outline-none dark:focus:ring-gray-800"

      :dark ->
        "rounded text-white bg-gray-700 hover:bg-gray-800 active:bg-gray-600 focus:ring-2 focus:ring-gray-600 dark:text-white dark:bg-gray-700 dark:hover:bg-gray-600 dark:active:bg-gray-500 focus:outline-none dark:focus:ring-gray-500"

      :info ->
        "rounded text-white bg-gray-500 hover:bg-gray-600 active:bg-gray-700 focus:ring-2 focus:ring-gray-400 dark:bg-gray-600 dark:hover:bg-gray-500 dark:active:bg-gray-400 focus:outline-none dark:focus:ring-gray-700"

      :success ->
        "rounded text-white bg-green-600 hover:bg-green-700 active:bg-green-800 focus:ring-2 focus:ring-green-700 dark:bg-green-600 dark:hover:bg-green-500 dark:active:bg-green-400 focus:outline-none dark:focus:ring-green-700"

      :warning ->
        "rounded text-white bg-yellow-500 hover:bg-yellow-600 active:bg-yellow-700 focus:ring-2 focus:ring-yellow-400 dark:bg-yellow-600 dark:hover:bg-yellow-500 dark:active:bg-yellow-400 focus:outline-none dark:focus:ring-yellow-700"

      :danger ->
        "rounded text-white bg-red-500 hover:bg-red-600 active:bg-red-700 focus:ring-2 focus:ring-red-400 dark:bg-red-600 dark:hover:bg-red-500 dark:active:bg-red-400 focus:outline-none dark:focus:ring-red-700"

      :link ->
        "rounded text-blue-500 hover:text-blue-600 active:text-blue-700 focus:ring-2 focus:ring-blue-400 dark:text-blue-600 dark:hover:text-blue-500 dark:active:text-blue-400 focus:outline-none dark:focus:ring-blue-700 hover:underline cursor-pointer"

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
  attr(:rest, :global, include: ~w(disabled form name value target rel download))

  slot(:inner_block, required: true)

  def button(assigns) do
    ~H"""
    <%= case @href do %>
      <% nil -> %>
        <button
          type={@type}
          class={[
            "whitespace-nowrap",
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
            "whitespace-nowrap",
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
  attr(:checked, :boolean, doc: "the checked flag for checkbox inputs")
  attr(:ctx, :map, default: nil)
  attr(:prompt, :string, default: nil, doc: "the prompt for select inputs")
  attr(:options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2")
  attr(:multiple, :boolean, default: false, doc: "the multiple flag for select inputs")

  attr(:rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)
  )

  slot(:inner_block)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id, field_value: field.value)
    |> assign(:errors, Enum.map(field.errors, &OliWeb.ErrorHelpers.translate_error(&1)))
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
      <label class="flex gap-2 items-center">
        <input type="hidden" name={@name} value="false" />
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
      <select id={@id} name={@name} class={@input_class} multiple={@multiple} {@rest}>
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.label :if={@label} for={@id} class={@label_class}>
        <%= @label %>
      </.label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="contents" phx-feedback-for={@name}>
      <.label :if={@label} for={@id}><%= @label %></.label>
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
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={@input_class}
        placeholder={@placeholder}
        {@rest}
      />
      <.label :if={@label} class={@label_class} for={@id}><%= @label %></.label>
      <.error :for={msg <- @errors}><%= msg %></.error>
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
      assigns.errors != [] && "border-red-400 focus:border-red-400"
    ]

    {group_class, label_class, input_class} =
      if assigns[:variant] == "outlined" do
        {"form-label-group", "control-label pointer-events-none", ["form-control" | input_class]}
      else
        {"flex flex-col-reverse", "", input_class}
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

  attr(:if, :boolean, default: true)

  def loader(assigns) do
    ~H"""
    <div :if={@if} class="h-full w-full flex items-center justify-center">
      <span
        class="spinner-border spinner-border-sm text-primary h-16 w-16"
        role="status"
        aria-hidden="true"
      />
    </div>
    """
  end

  attr(:percent, :integer, required: true)
  attr(:width, :string, default: "100%")
  attr(:show_percent, :boolean, default: true)
  attr(:role, :string, default: "progress_bar")

  def progress_bar(assigns) do
    ~H"""
    <div class="flex flex-row items-center mx-auto" role={@role}>
      <div class="flex justify-center w-full">
        <div
          class="rounded-[60px] bg-gray-200 h-1 dark:bg-[rgba(170,170,170,0.20)]"
          style={"width: #{@width}"}
        >
          <div class="rounded-[60px] bg-[#1E9531] dark:bg-white h-1" style={"width: #{@percent}%"}>
          </div>
        </div>
      </div>
      <div
        :if={@show_percent}
        class="ml-[6px] text-[16px] dark:text-[#DDD] leading-[32px] tracking-[0.02px] font-semibold"
      >
        <%= @percent %>%
      </div>
    </div>
    """
  end
end
