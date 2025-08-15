defmodule OliWeb.Certificates.Components.ThresholdsTab do
  use OliWeb, :live_component
  import OliWeb.Components.Delivery.Buttons, only: [toggle_chevron: 1]

  alias Oli.Delivery.Sections.{Certificate, Section}
  alias Oli.Repo
  alias OliWeb.Icons

  def update(assigns, socket) do
    certificate = assigns.certificate

    custom_assessments =
      case certificate do
        nil -> []
        cert -> cert.custom_assessments
      end

    graded_pages_options =
      Enum.map(
        assigns.graded_pages,
        &Map.put(&1, :selected, &1.resource_id in custom_assessments)
      )

    selected_graded_pages_options =
      Enum.reduce(graded_pages_options, %{}, fn option, acc ->
        if option.selected,
          do: Map.put(acc, option.resource_id, option.title),
          else: acc
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       section_changeset: Section.changeset(assigns.section),
       certificate_changeset: certificate_changeset(certificate),
       graded_pages_options: graded_pages_options,
       selected_graded_pages_options: selected_graded_pages_options,
       selected_ids: custom_assessments
     )}
  end

  def render(assigns) do
    ~H"""
    <div class={["w-full flex-col", if(@read_only, do: "opacity-70")]}>
      <div class="text-base font-medium mb-12">
        Customize the conditions students must meet to receive a certificate.
      </div>
      <div class="flex flex-row items-center gap-4 mb-11">
        <Icons.lock :if={@read_only} />
        <div class="text-xl font-normal ">Completion & Scoring</div>
      </div>
      <.form for={%{}} id="multiselect_form" phx-target={@myself} phx-change="toggle_selected">
      </.form>
      <.form
        :let={f}
        id="certificate_form"
        for={@certificate_changeset}
        phx-target={@myself}
        phx-submit="save_certificate"
        phx-change="validate"
        class="w-full justify-start items-center gap-3"
      >
        <fieldset disabled={@read_only}>
          <.input field={f[:section_id]} type="hidden" value={@section.id} />
          <.input
            field={f[:assessments_apply_to]}
            type="hidden"
            value={if length(@selected_ids) == length(@graded_pages_options), do: :all, else: :custom}
          />

          <div class="w-3/4 flex-col justify-start items-start gap-10 inline-flex">
            <div class="self-stretch flex-col justify-start items-start gap-[60px] flex">
              <div class="w-full flex-col justify-start items-start gap-10 flex">
                <div class="self-stretch flex-col justify-start items-start gap-10 flex">
                  <div class="self-stretch flex-col justify-start items-start gap-10 flex">
                    <div class="self-stretch flex-col justify-start items-start gap-3 flex">
                      <div class="justify-start items-center gap-3 inline-flex">
                        <Icons.discussions class={
                          if(@read_only,
                            do: "stroke-[#757682]",
                            else: "dark:stroke-white stroke-black"
                          )
                        } />
                        <div class="text-base font-bold">
                          Required Discussion Posts
                        </div>
                      </div>
                      <div class="w-full text-base font-medium">
                        <.input
                          type="number"
                          min="0"
                          field={f[:required_discussion_posts]}
                          errors={f.errors}
                          class="pl-6 border-[#D4D4D4] rounded"
                        />
                      </div>
                    </div>
                    <div class="self-stretch flex-col justify-start items-start gap-3 flex">
                      <div class="justify-start items-center gap-3 inline-flex">
                        <Icons.message_circles />
                        <div class="text-base font-bold">
                          Required Class Notes
                        </div>
                      </div>
                      <div class="w-full text-base font-medium">
                        <.input
                          type="number"
                          min="0"
                          field={f[:required_class_notes]}
                          errors={f.errors}
                          class="pl-6 border-[#D4D4D4] rounded"
                        />
                      </div>
                    </div>
                  </div>
                  <div class="self-stretch flex-col justify-start items-center gap-10 flex">
                    <div class="self-stretch flex-col justify-start items-start gap-3 flex">
                      <div class="self-stretch h-auto flex-col justify-start items-start gap-5 flex">
                        <div class="justify-start items-center gap-3 inline-flex">
                          <Icons.transparent_flag />

                          <div class="text-base font-bold">
                            Required Scored Pages
                          </div>
                        </div>
                        <div class="self-stretch">
                          <span class="text-base font-medium">
                            To earn a <b>Certificate of Completion</b>, students must score a minimum of:
                          </span>
                        </div>
                      </div>

                      <div class="w-full text-base font-medium relative">
                        <.input
                          type="number"
                          min="0"
                          max="100.0"
                          step="0.1"
                          field={f[:min_percentage_for_completion]}
                          class="pl-6 border-[#D4D4D4] rounded"
                        />

                        <span class={[
                          "absolute right-8 transform -translate-y-1/2 text-gray-500 pointer-events-none ",
                          if(f.errors != [], do: "top-1/3", else: "top-1/2")
                        ]}>
                          %
                        </span>
                      </div>
                    </div>
                    <div class="self-stretch flex-col justify-start items-start gap-3 flex">
                      <div class="self-stretch">
                        <span class="text-base font-medium">
                          To earn a <b>Certificate with Distinction</b>, students must score a minimum of:
                        </span>
                      </div>
                      <div class="w-full text-base font-medium relative">
                        <.input
                          type="number"
                          min="0"
                          max="100.0"
                          step="0.1"
                          field={f[:min_percentage_for_distinction]}
                          errors={f.errors}
                          class="pl-6 border-[#D4D4D4] rounded"
                        />
                        <span class="absolute right-8 top-1/2 transform -translate-y-1/2 text-gray-500 pointer-events-none">
                          %
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="w-full flex-col justify-start items-start gap-3 flex">
                  <div class="self-stretch text-[#c03a2b] text-base font-medium">
                    *On the following scored pages:
                  </div>
                  <div
                    class="w-full flex items-center text-base font-medium border border-[#D4D4D4] rounded bg-white dark:bg-gray-800"
                    style="min-height: 2.75rem;"
                  >
                    <.multi_select
                      id="graded_pages"
                      placeholder="Select scored pages..."
                      options={@graded_pages_options}
                      target={@myself}
                      selected_values={@selected_graded_pages_options}
                      selected_resource_ids={@selected_ids}
                      disabled={@read_only}
                    />
                  </div>
                  <% errors = f.errors[:custom_assessments] %>
                  <.error :if={errors}>{elem(errors, 0)}</.error>
                </div>
              </div>
              <div class="flex flex-row justify-start items-start gap-[152px]">
                <div class="pt-[7px] pb-[5px] flex-col justify-center items-start gap-1 inline-flex">
                  <div class="flex flex-row items-center gap-4">
                    <Icons.lock :if={@read_only} />
                    <div class="text-xl font-normal">
                      Certificate Approval
                    </div>
                  </div>

                  <div class="w-96 h-14 text-neutral-500 text-base font-medium">
                    Require instructor approval before registering credentials to students.
                  </div>
                </div>
                <div class="h-6 justify-start items-center gap-3 flex">
                  <div class="h-6 justify-start items-center gap-3 flex">
                    <.input
                      type="checkbox"
                      field={f[:requires_instructor_approval]}
                      errors={f.errors}
                      class="form-check-input w-5 h-5 p-0.5"
                    />
                    <div class="grow shrink basis-0 text-base font-medium">
                      Require instructor approval
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div
              :if={!@read_only}
              class="px-6 py-4 bg-[#0165da] rounded-[3px] justify-center items-center gap-2 inline-flex overflow-hidden opacity-90 hover:opacity-100 cursor-pointer"
            >
              <button
                type="submit"
                form="certificate_form"
                class="text-white text-base font-bold"
                phx-target={@myself}
              >
                Save Thresholds
              </button>
            </div>
          </div>
        </fieldset>
      </.form>
    </div>
    """
  end

  def handle_event("validate", %{"certificate" => certificate_params}, socket) do
    changeset =
      cast_certificate_params(
        certificate_params,
        socket.assigns.certificate,
        socket.assigns.section,
        socket.assigns.selected_ids
      )

    {:noreply, assign(socket, certificate_changeset: changeset)}
  end

  def handle_event("save_certificate", params, socket) do
    socket =
      cast_certificate_params(
        params["certificate"],
        socket.assigns.certificate,
        socket.assigns.section,
        socket.assigns.selected_ids
      )
      |> Repo.insert_or_update()
      |> case do
        {:ok, certificate} ->
          send(self(), {:put_flash, [:info, "Certificate settings saved successfully"]})

          assign(socket,
            certificate: certificate,
            certificate_changeset: certificate_changeset(certificate)
          )

        {:error, %Ecto.Changeset{} = changeset} ->
          send(self(), {:put_flash, [:error, "Failed to save certificate settings"]})

          assign(socket, certificate_changeset: changeset)
      end

    {:noreply, socket}
  end

  def handle_event("toggle_selected", %{"_target" => [id]}, socket),
    do: do_update_selection(socket, String.to_integer(id))

  def handle_event("toggle_selected", %{"resource_id" => id}, socket),
    do: do_update_selection(socket, String.to_integer(id))

  def handle_event("toggle_selected", _params, socket), do: {:noreply, socket}

  def handle_event("select_all_pages", _params, socket) do
    graded_pages_options = Enum.map(socket.assigns.graded_pages, &Map.put(&1, :selected, true))

    selected_graded_pages_options =
      Enum.reduce(graded_pages_options, %{}, fn option, acc ->
        Map.put(acc, option.resource_id, option.title)
      end)

    {:noreply,
     assign(socket,
       graded_pages_options: graded_pages_options,
       selected_graded_pages_options: selected_graded_pages_options,
       selected_ids: Map.keys(selected_graded_pages_options)
     )}
  end

  def handle_event("deselect_all_pages", _params, socket) do
    graded_pages_options = Enum.map(socket.assigns.graded_pages, &Map.put(&1, :selected, false))

    {:noreply,
     assign(socket,
       graded_pages_options: graded_pages_options,
       selected_graded_pages_options: %{},
       selected_ids: []
     )}
  end

  attr :id, :string
  attr :placeholder, :string, default: "Select an option"
  attr :disabled, :boolean, default: false
  attr :options, :list, required: true
  attr :target, :map, required: true
  attr :selected_values, :map, required: true
  attr :selected_resource_ids, :list, required: true

  def multi_select(assigns) do
    ~H"""
    <div class="flex flex-col w-full">
      <div
        phx-click={
          if(!@disabled,
            do:
              JS.toggle(to: "##{@id}-options-container")
              |> JS.toggle(to: "##{@id}-down-icon")
              |> JS.toggle(to: "##{@id}-up-icon")
          )
        }
        class={[
          "flex gap-x-4 px-4 justify-between items-center w-auto hover:cursor-pointer",
          if(@disabled, do: "hover:cursor-not-allowed")
        ]}
        id={"#{@id}-selected-options-container"}
      >
        <div class="flex gap-1 flex-wrap border-[#D4D4D4] rounded py-2">
          <span
            :if={@selected_values == %{}}
            class="px-3 text-[#383a44] text-base font-medium leading-none dark:text-white"
          >
            {@placeholder}
          </span>
          <span :if={@selected_values != %{}}>
            <.show_selected_pages
              selected_values={@selected_values}
              target={@target}
              disabled={@disabled}
            />
          </span>
        </div>
        <.toggle_chevron id={@id} map_values={@selected_values} />
      </div>
      <div class="w-full relative">
        <div
          class="w-full max-h-60 py-4 hidden z-50 absolute dark:bg-gray-800 bg-white border overflow-y-scroll top-1 rounded"
          id={"#{@id}-options-container"}
          phx-click-away={
            JS.hide() |> JS.hide(to: "##{@id}-up-icon") |> JS.show(to: "##{@id}-down-icon")
          }
        >
          <div class="flex flex-row items-center justify-start px-4 gap-x-4">
            <% select_all_disabled? = Enum.all?(@options, & &1.selected) %>
            <button
              type="button"
              class={[
                "px-4 py-2 rounded justify-center items-center gap-2 inline-flex opacity-90 text-right text-white text-xs font-semibold leading-none",
                if(select_all_disabled?,
                  do: "cursor-not-allowed bg-gray-300",
                  else: "bg-blue-500 hover:opacity-100"
                )
              ]}
              phx-click="select_all_pages"
              phx-target={@target}
              disabled={select_all_disabled?}
            >
              Select All
            </button>
            <% deselect_all_disabled? = @selected_resource_ids == [] %>

            <button
              type="button"
              class={[
                "px-4 py-2 rounded justify-center items-center gap-2 inline-flex opacity-90 text-right text-white text-xs font-semibold leading-none",
                if(deselect_all_disabled?,
                  do: "cursor-not-allowed bg-gray-300",
                  else: "bg-blue-500 hover:opacity-100"
                )
              ]}
              phx-click="deselect_all_pages"
              phx-target={@target}
              disabled={deselect_all_disabled?}
            >
              Deselect All
            </button>
          </div>
          <div class="w-full border border-gray-200 my-3"></div>

          <div class="flex flex-column gap-y-3 px-4">
            <.input
              :for={option <- @options}
              name={option.resource_id}
              value={option.selected}
              label={option.title}
              checked={option.resource_id in @selected_resource_ids}
              type="checkbox"
              label_class="text-zinc-900 text-xs font-normal leading-none dark:text-white"
              form="multiselect_form"
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :selected_values, :map, required: true
  attr :target, :map, required: true
  attr :disabled, :boolean, default: false

  defp show_selected_pages(assigns) do
    ~H"""
    <div
      :for={{id, title} <- @selected_values}
      class="text-white inline-flex items-center text-xs font-medium bg-[#0165da] border rounded-full px-2 py-0.5 m-0.5"
    >
      <span>{title}</span>
      <button
        type="button"
        class={[
          "ml-1.5 text-black rounded-full w-5 h-5 flex items-center justify-center",
          if(@disabled, do: "cursor-not-allowed", else: "hover:bg-[#3383e1]")
        ]}
        aria-label="Remove"
        phx-click="toggle_selected"
        phx-value-resource_id={id}
        phx-target={@target}
      >
        <Icons.cross />
      </button>
    </div>
    """
  end

  defp do_update_selection(socket, selected_id) do
    %{graded_pages_options: graded_pages_options} = socket.assigns

    updated_options =
      Enum.map(graded_pages_options, fn option ->
        if option.resource_id == selected_id,
          do: %{option | selected: !option.selected},
          else: option
      end)

    {selected_graded_pages_options, selected_ids} =
      Enum.reduce(updated_options, {%{}, []}, fn option, {values, acc_ids} ->
        if option.selected,
          do: {Map.put(values, option.resource_id, option.title), [option.resource_id | acc_ids]},
          else: {values, acc_ids}
      end)

    {:noreply,
     assign(socket,
       selected_graded_pages_options: selected_graded_pages_options,
       graded_pages_options: updated_options,
       selected_ids: selected_ids
     )}
  end

  defp cast_certificate_params(params, certificate, section, selected_ids) do
    params =
      Enum.reduce(params, %{}, fn {key, value}, acc ->
        case cast_value(key, value) do
          nil -> acc
          value -> Map.put(acc, key, value)
        end
      end)
      |> Map.merge(%{
        "custom_assessments" => selected_ids,
        "title" => section.title,
        "description" => section.description || "Certificate description"
      })

    Certificate.changeset(certificate || %Certificate{}, params)
  end

  defp cast_value(_, value) when value in ["", nil], do: nil
  defp cast_value("min_percentage_for_completion", value), do: Float.parse(value) |> elem(0)
  defp cast_value("min_percentage_for_distinction", value), do: Float.parse(value) |> elem(0)
  defp cast_value("required_discussion_posts", value), do: String.to_integer(value)
  defp cast_value("required_class_notes", value), do: String.to_integer(value)
  defp cast_value("section_id", value), do: String.to_integer(value)
  defp cast_value("requires_instructor_approval", value), do: Oli.Utils.string_to_boolean(value)
  defp cast_value("assessments_apply_to", value), do: String.to_existing_atom(value)
  defp cast_value(_, value), do: value

  defp certificate_changeset(nil), do: Certificate.changeset()
  defp certificate_changeset(%Certificate{} = cert), do: Certificate.changeset(cert, %{})
end
