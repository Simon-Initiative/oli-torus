defmodule OliWeb.SystemMessageLive.IndexView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  import OliWeb.ErrorHelpers

  alias Oli.Notifications
  alias Oli.Notifications.{PubSub, SystemMessage}
  alias OliWeb.Common.{Breadcrumb, Confirm}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.SystemMessageLive.EditMessage
  alias Surface.Components.Form
  alias Surface.Components.Form.{ErrorTag, Field, TextArea}

  data title, :string, default: "Type a System Message"
  data breadcrumbs, :list
  data show_confirm, :boolean, default: false
  data messages, :list
  data unsaved_system_message, :map, default: nil
  data message_will_be_displayed, :boolean

  def breadcrumb() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "New System Message",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(_, %{"local_tz" => local_tz}, socket) do
    messages = Notifications.list_system_messages()

    {:ok,
     assign(socket,
       messages: messages,
       local_tz: local_tz,
       breadcrumbs: breadcrumb()
     )}
  end

  def render(assigns) do
    ~F"""
      {#for message <- @messages}
        <EditMessage system_message={current_message(@unsaved_system_message, message)} timezone={@local_tz}/>
      {/for}
      <Form for={:system_message} submit="create">
        <Field name={:message} class="form-group">
          <TextArea
            class="form-control"
            rows="3"
            opts={placeholder: "Type a message for all users in the system", maxlength: "140"}
          />
          <ErrorTag/>
        </Field>

        <button class="form-button btn btn-md btn-primary btn-block mt-3" type="submit">Create</button>
      </Form>
      {#if @show_confirm}
        <Confirm title="Confirm Message" id="dialog" ok="broadcast_message" cancel="cancel_modal">
          Are you sure that you wish to <b> {if @message_will_be_displayed, do: "send", else: "hide"}</b> this message to all users in the system?
        </Confirm>
      {/if}
    """
  end

  def handle_event("create", %{"system_message" => %{"message" => message}}, socket) do
    socket = clear_flash(socket)

    case Notifications.create_system_message(%{message: message}) do
      {:ok, _system_message} ->
        {:noreply,
         socket
         |> put_flash(:info, "System message successfully created.")
         |> assign(messages: Notifications.list_system_messages())}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          put_flash(
            socket,
            :error,
            "System message couldn't be created: #{translate_all_changeset_errors(changeset)}."
          )

        {:noreply, socket}
    end
  end

  def handle_event(
        "save",
        %{"system_message" => %{"active" => active, "id" => id} = attrs},
        socket
      ) do
    socket = clear_flash(socket)

    active = Oli.Utils.string_to_boolean(active)
    id = String.to_integer(id)
    system_message = find_system_message(id, socket.assigns.messages)

    message_attrs =
      attrs
      |> Oli.Utils.atomize_keys()
      |> Map.update(:start, "", &datestring_to_utc_datetime(&1, socket.assigns.local_tz))
      |> Map.update(:end, "", &datestring_to_utc_datetime(&1, socket.assigns.local_tz))
      |> Map.put(:active, active)
      |> Map.put(:id, id)

    message_was_being_displayed =
      system_message
      |> Map.from_struct()
      |> message_displayed?()

    message_will_be_displayed = message_displayed?(message_attrs)

    # only show confirmation modal when:
    # - the system message changed its status (was being displayed but not anymore, or vice versa) OR
    # - the system message was being displayed and the message content changed
    show_confirm =
      message_was_being_displayed != message_will_be_displayed or
        (message_was_being_displayed and attrs["message"] != system_message.message)

    socket =
      if show_confirm do
        assign(socket,
          unsaved_system_message: message_attrs,
          show_confirm: true,
          message_will_be_displayed: message_will_be_displayed
        )
      else
        case Notifications.update_system_message(system_message, Map.delete(message_attrs, :id)) do
          {:ok, _system_message} ->
            socket
            |> put_flash(:info, "System message successfully updated.")
            |> assign(messages: Notifications.list_system_messages())

          {:error, %Ecto.Changeset{} = changeset} ->
            put_flash(
              socket,
              :error,
              "System message couldn't be updated: #{translate_all_changeset_errors(changeset)}."
            )
        end
      end

    {:noreply, socket}
  end

  def handle_event("cancel_modal", _, socket) do
    {:noreply, assign(socket, show_confirm: false, unsaved_system_message: nil)}
  end

  def handle_event("_bsmodal.unmount", _, socket) do
    {:noreply, assign(socket, show_confirm: false, unsaved_system_message: nil)}
  end

  def handle_event("broadcast_message", _params, socket) do
    socket = clear_flash(socket)

    {id, new_message_attrs} = Map.pop(socket.assigns.unsaved_system_message, :id)

    system_message = find_system_message(id, socket.assigns.messages)

    socket =
      case Notifications.update_system_message(system_message, new_message_attrs) do
        {:ok, updated_system_message} ->
          if socket.assigns.message_will_be_displayed do
            updated_system_message
            |> Map.from_struct()
            |> PubSub.display_system_message()
          else
            updated_system_message
            |> Map.from_struct()
            |> PubSub.hide_system_message()
          end

          socket
          |> put_flash(:info, "System message successfully updated.")
          |> assign(messages: Notifications.list_system_messages())

        {:error, %Ecto.Changeset{} = changeset} ->
          put_flash(
            socket,
            :error,
            "System message couldn't be updated: #{translate_all_changeset_errors(changeset)}."
          )
      end

    {:noreply, assign(socket, show_confirm: false, unsaved_system_message: nil)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    socket = clear_flash(socket)

    message =
      id
      |> String.to_integer()
      |> find_system_message(socket.assigns.messages)

    socket =
      case Notifications.delete_system_message(message) do
        {:ok, _system_message} ->
          if message.active and message_in_date_range(message) do
            message
            |> Map.from_struct()
            |> PubSub.hide_system_message()
          end

          socket
          |> put_flash(:info, "System message successfully deleted.")
          |> assign(messages: Notifications.list_system_messages())

        {:error, %Ecto.Changeset{}} ->
          put_flash(
            socket,
            :error,
            "System message couldn't be deleted."
          )
      end

    {:noreply, socket}
  end

  defp find_system_message(id, messages) do
    Enum.find(messages, fn m -> m.id == id end)
  end

  defp current_message(%{id: id} = unsaved_system_message, %SystemMessage{id: id} = message) do
    message
    |> Notifications.change_system_message(unsaved_system_message)
    |> Ecto.Changeset.apply_changes()
  end

  defp current_message(_unsaved_system_message, message), do: message

  defp message_in_date_range(%{start: start_time, end: end_time}) do
    now = DateTime.utc_now()

    (is_nil(start_time) or DateTime.compare(start_time, now) == :lt) and
      (is_nil(end_time) or DateTime.compare(now, end_time) == :lt)
  end

  defp message_displayed?(%{active: active} = attrs) do
    active and message_in_date_range(attrs)
  end

  defp datestring_to_utc_datetime("", _), do: nil

  defp datestring_to_utc_datetime(date_string, local_tz) do
    date_string
    |> Timex.parse!("{ISO:Extended}")
    |> Timex.to_datetime(local_tz)
    |> DateTime.shift_zone("Etc/UTC")
    |> elem(1)
  end
end
