defmodule OliWeb.Certificates.CertificateSettingsComponent do
  use OliWeb, :live_component

  import OliWeb.Components.Delivery.Buttons, only: [toggle_chevron: 1]

  alias Oli.Repo
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Certificate, Section}
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
       product_changeset: Section.changeset(assigns.product),
       certificate_changeset: certificate_changeset(certificate),
       graded_pages_options: graded_pages_options,
       selected_graded_pages_options: selected_graded_pages_options,
       selected_ids: custom_assessments
     )}
  end

  def handle_event("validate", %{"certificate" => certificate_params}, socket) do
    changeset =
      cast_certificate_params(
        certificate_params,
        socket.assigns.product,
        socket.assigns.selected_ids
      )

    {:noreply, assign(socket, certificate_changeset: changeset)}
  end

  def handle_event("save_certificate", params, socket) do
    socket =
      cast_certificate_params(
        params["certificate"],
        socket.assigns.product,
        socket.assigns.selected_ids
      )
      |> Repo.insert_or_update()
      |> case do
        {:ok, certificate} ->
          send(self(), {:put_flash, [:info, "Certificate settings saved successfully"]})

          assign(socket, certificate_changeset: certificate_changeset(certificate))

        {:error, %Ecto.Changeset{} = changeset} ->
          send(self(), {:put_flash, [:error, "Failed to save certificate settings"]})

          assign(socket, certificate_changeset: changeset)
      end

    {:noreply, socket}
  end

  def handle_event("toggle_certificate", params, socket) do
    certificate_enabled = params["certificate_enabled"] == "on"

    case Sections.update_section(socket.assigns.product, %{
           certificate_enabled: certificate_enabled
         }) do
      {:ok, product} ->
        {:noreply,
         assign(socket, product: product, product_changeset: Section.changeset(product))}

      {:error, changeset} ->
        {:noreply, assign(socket, product_changeset: changeset)}
    end
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

  def render(assigns) do
    ~H"""
    <div class="w-full flex-col justify-start items-start gap-[30px] inline-flex">
      <div role="title" class="self-stretch text-2xl font-normal">
        Certificate Settings
      </div>
      <.form
        for={@product_changeset}
        phx-target={@myself}
        phx-change="toggle_certificate"
        class="self-stretch justify-start items-center gap-3 inline-flex"
      >
        <input
          type="checkbox"
          class="form-check-input w-5 h-5 p-0.5"
          id="enable_certificates_checkbox"
          name="certificate_enabled"
          checked={Ecto.Changeset.get_field(@product_changeset, :certificate_enabled)}
        />
        <div class="grow shrink basis-0 text-base font-medium">
          Enable certificate capabilities for this product
        </div>
      </.form>
      <div class="flex mt-10 mb-2 gap-20">
        <div class="justify-start">
          <.link
            class={[
              "text-base font-bold hover:text-[#0165da] dark:hover:text-[#0165da]",
              if(@active_tab == :thresholds,
                do: "underline text-[#0165da]",
                else: "text-black dark:text-white no-underline hover:no-underline"
              )
            ]}
            patch={@current_path <> "?active_tab=thresholds"}
          >
            Thresholds
          </.link>
        </div>
        <div class="justify-center items-center inline-flex">
          <.link
            class={[
              "text-base font-bold hover:text-[#0165da] dark:hover:text-[#0165da]",
              if(@active_tab == :design,
                do: "underline text-[#0165da]",
                else: "text-black dark:text-white no-underline hover:no-underline"
              )
            ]}
            patch={@current_path <> "?active_tab=design"}
          >
            Design
          </.link>
        </div>
        <div class="justify-end items-center inline-flex">
          <.link
            class={[
              "text-base font-bold hover:text-[#0165da] dark:hover:text-[#0165da]",
              if(@active_tab == :credentials_issued,
                do: "underline text-[#0165da]",
                else: "text-black dark:text-white no-underline hover:no-underline"
              )
            ]}
            patch={@current_path <> "?active_tab=credentials_issued"}
          >
            Credentials Issued
          </.link>
        </div>
      </div>
      <.tab_content
        active_tab={@active_tab}
        certificate_changeset={@certificate_changeset}
        target={@myself}
        graded_pages_options={@graded_pages_options}
        selected_graded_pages_options={@selected_graded_pages_options}
        selected_ids={@selected_ids}
        section_id={@product.id}
      />
    </div>
    """
  end

  attr :active_tab, :atom, required: true
  attr :certificate_changeset, :map, required: true
  attr :target, :any, required: true
  attr :graded_pages_options, :map, required: true
  attr :selected_graded_pages_options, :map, required: true
  attr :selected_ids, :list, required: true
  attr :section_id, :integer, required: true

  defp tab_content(%{active_tab: :thresholds} = assigns) do
    ~H"""
    <div class="w-full flex-col">
      <div class="mb-14 text-base font-medium">
        Customize the conditions students must meet to receive a certificate.
      </div>
      <div class="mb-11 text-xl font-normal">Completion & Scoring</div>
      <.form for={%{}} id="multiselect_form" phx-target={@target} phx-change="toggle_selected">
      </.form>
      <.form
        :let={f}
        id="certificate_form"
        for={@certificate_changeset}
        phx-target={@target}
        phx-submit="save_certificate"
        phx-change="validate"
        class="w-full justify-start items-center gap-3"
      >
        <.input field={f[:section_id]} type="hidden" value={@section_id} />
        <.input
          field={f[:assessments_apply_to]}
          type="hidden"
          value={if @selected_ids == [], do: :all, else: :custom}
        />

        <div class="w-3/4 flex-col justify-start items-start gap-10 inline-flex">
          <div class="self-stretch flex-col justify-start items-start gap-[60px] flex">
            <div class="w-full flex-col justify-start items-start gap-10 flex">
              <div class="self-stretch flex-col justify-start items-start gap-10 flex">
                <div class="self-stretch flex-col justify-start items-start gap-10 flex">
                  <div class="self-stretch flex-col justify-start items-start gap-3 flex">
                    <div class="justify-start items-center gap-3 inline-flex">
                      <Icons.discussions class="dark:stroke-white stroke-black" />
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
                        errors={f.errors}
                        class="pl-6 border-[#D4D4D4] rounded"
                      />
                      <span class="absolute right-8 top-1/2 transform -translate-y-1/2 text-gray-500 pointer-events-none">
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
                    target={@target}
                    selected_values={@selected_graded_pages_options}
                    selected_resource_ids={@selected_ids}
                  />
                </div>
              </div>
            </div>
            <div class="flex flex-row justify-start items-start gap-[152px]">
              <div class="pt-[7px] pb-[5px] flex-col justify-center items-start gap-1 inline-flex">
                <div class="text-xl font-normal">
                  Certificate Approval
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
          <div class="px-6 py-4 bg-[#0165da] rounded-[3px] justify-center items-center gap-2 inline-flex overflow-hidden opacity-90 hover:opacity-100 cursor-pointer">
            <button
              type="submit"
              form="certificate_form"
              class="text-white text-base font-bold"
              phx-target={@target}
            >
              Save Thresholds
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp tab_content(%{active_tab: :design} = assigns) do
    ~H"""
    <div class="w-full flex-col">
      <div class="mb-14 text-base font-medium">
        Create and preview your certificate.
      </div>

      <.form
        :let={f}
        id="design_form"
        for={@certificate_changeset}
        phx-target={@target}
        phx-submit="save_certificate"
        class="w-full justify-start items-center gap-3"
      >
        <div class="w-3/4 flex-col justify-start items-start gap-10 inline-flex">
          <!-- Title -->
          <div class="self-stretch flex-col justify-start items-start gap-3 flex">
            <div class="text-base font-bold">
              Course Title
            </div>
            <div class="w-full text-base">
              <.input
                type="text"
                field={f[:title]}
                value={@certificate_changeset.data.title}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
            </div>
          </div>
          <!-- Subtitle -->
          <div class="self-stretch flex-col justify-start items-start gap-3 flex">
            <div class="text-base font-bold">
              Subtitle
            </div>
            <div class="text-base font-small">
              The description that appears under the name of the awardee
            </div>
            <div class="w-full text-base font-medium">
              <.input
                type="text"
                field={f[:description]}
                value={@certificate_changeset.data.description}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
            </div>
          </div>
          <!-- Administrators -->
          <div class="self-stretch flex-col justify-start items-start gap-3 flex">
            <div class="text-base font-bold">
              Administrators
            </div>
            <div class="text-base font-small">
              Include up to three administrators on your certificate.
            </div>
            <div class="flex gap-3 items-center">
              <.input
                type="text"
                field={f[:admin_name1]}
                placeholder="Name 1"
                value={@certificate_changeset.data.admin_name1}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
              <.input
                type="text"
                field={f[:admin_title1]}
                placeholder="Title 1"
                value={@certificate_changeset.data.admin_title1}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
            </div>
            <div class="flex gap-3 items-center">
              <.input
                type="text"
                field={f[:admin_name2]}
                placeholder="Name 2"
                value={@certificate_changeset.data.admin_name2}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
              <.input
                type="text"
                field={f[:admin_title2]}
                placeholder="Title 2"
                value={@certificate_changeset.data.admin_title2}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
            </div>
            <div class="flex gap-3 items-center">
              <.input
                type="text"
                field={f[:admin_name3]}
                placeholder="Name 3"
                value={@certificate_changeset.data.admin_name3}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
              <.input
                type="text"
                field={f[:admin_title3]}
                placeholder="Title 3"
                value={@certificate_changeset.data.admin_title3}
                errors={f.errors}
                class="pl-6 border-[#D4D4D4] rounded"
              />
            </div>
          </div>
          <!-- Logos -->
          <div class="self-stretch flex-col justify-start items-start gap-3 flex">
            <div class="text-base font-bold">
              Logos
            </div>
            <div class="text-sm text-gray-500">
              Upload up to three logos for your certificate.
            </div>
            <!-- TODO: Display Current Logos -->
            <!-- TODO: File Upload Input -->
          </div>
          <!-- TODO: Preview and Save -->
        </div>
      </.form>
    </div>
    """
  end

  defp tab_content(%{active_tab: :credentials_issued} = assigns) do
    ~H"""
    """
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
          if(@disabled, do: "bg-gray-300 hover:cursor-not-allowed")
        ]}
        id={"#{@id}-selected-options-container"}
      >
        <div class="flex gap-1 flex-wrap border-[#D4D4D4] rounded py-2">
          <span
            :if={@selected_values == %{}}
            class="px-3 text-[#383a44] text-base font-medium leading-none dark:text-white"
          >
            <%= @placeholder %>
          </span>
          <span :if={@selected_values != %{}}>
            <.show_selected_pages selected_values={@selected_values} target={@target} />
          </span>
        </div>
        <.toggle_chevron id={@id} map_values={@selected_values} />
      </div>
      <div class="w-full relative">
        <div
          class="w-full h-60 py-4 hidden z-50 absolute dark:bg-gray-800 bg-white border overflow-y-scroll top-1 rounded"
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

  defp show_selected_pages(assigns) do
    ~H"""
    <div
      :for={{id, title} <- @selected_values}
      class="inline-flex items-center text-xs font-medium bg-slate-300 text-slate-800 border border-slate-400 dark:bg-slate-700 dark:text-slate-200 dark:border-slate-400 rounded-full px-2 py-0.5 m-0.5"
    >
      <span><%= title %></span>
      <button
        type="button"
        class="ml-1.5 hover:bg-slate-400 dark:hover:bg-slate-500 rounded-full w-4 h-4 flex items-center justify-center"
        aria-label="Remove"
        phx-click="toggle_selected"
        phx-value-resource_id={id}
        phx-target={@target}
      >
        &times;
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

  defp cast_certificate_params(params, section, selected_ids) do
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

    Certificate.changeset(section.certificate || %Certificate{}, params)
    |> IO.inspect(label: "cast")
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
