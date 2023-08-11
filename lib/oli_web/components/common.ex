defmodule OliWeb.Components.Common do
  use Phoenix.Component

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

  @doc """
  Button component

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr(:variant, :atom, default: nil, values: [:primary, :info, :success, :warning, :danger, nil])
  attr(:type, :string, default: nil)
  attr(:class, :string, default: nil)
  attr(:rest, :global, include: ~w(disabled form name value))

  slot(:inner_block, required: true)

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "rounded text-sm px-3.5 py-2",
        button_variant_classes(@variant),
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp button_variant_classes(variant) do
    case variant do
      :primary ->
        "text-white bg-blue-500 hover:bg-blue-600 active:bg-blue-700 focus:ring-2 focus:ring-blue-400 dark:bg-blue-600 dark:hover:bg-blue-500 dark:active:bg-blue-400 focus:outline-none dark:focus:ring-blue-700"

      :info ->
        "text-white bg-gray-500 hover:bg-gray-600 active:bg-gray-700 focus:ring-2 focus:ring-gray-400 dark:bg-gray-600 dark:hover:bg-gray-500 dark:active:bg-gray-400 focus:outline-none dark:focus:ring-gray-700"

      :success ->
        "text-white bg-green-500 hover:bg-green-600 active:bg-green-700 focus:ring-2 focus:ring-green-400 dark:bg-green-600 dark:hover:bg-green-500 dark:active:bg-green-400 focus:outline-none dark:focus:ring-green-700"

      :warning ->
        "text-white bg-yellow-500 hover:bg-yellow-600 active:bg-yellow-700 focus:ring-2 focus:ring-yellow-400 dark:bg-yellow-600 dark:hover:bg-yellow-500 dark:active:bg-yellow-400 focus:outline-none dark:focus:ring-yellow-700"

      :danger ->
        "text-white bg-red-500 hover:bg-red-600 active:bg-red-700 focus:ring-2 focus:ring-red-400 dark:bg-red-600 dark:hover:bg-red-500 dark:active:bg-red-400 focus:outline-none dark:focus:ring-red-700"

      _ ->
        ""
    end
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

  attr(:type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)
  )

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"
  )

  attr(:errors, :list, default: [])
  attr(:class, :string, default: nil)
  attr(:checked, :boolean, doc: "the checked flag for checkbox inputs")
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
    |> assign(field: nil, id: assigns.id || field.id)
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
      <label class="contents">
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
    ~H"""
    <div class="contents" phx-feedback-for={@name}>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <select id={@id} name={@name} class={@class} multiple={@multiple} {@rest}>
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
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

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
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
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot(:inner_block, required: true)

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 phx-no-feedback:hidden">
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders a label.
  """
  attr(:for, :string, default: nil)
  attr(:if, :boolean, default: true)
  slot(:inner_block, required: true)

  def label(assigns) do
    ~H"""
    <label :if={@if} for={@for} class="block text-sm font-semibold leading-6 text-zinc-800">
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
end
