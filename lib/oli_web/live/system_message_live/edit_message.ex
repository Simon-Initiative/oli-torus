defmodule OliWeb.SystemMessageLive.EditMessage do
  use OliWeb, :html

  alias Oli.Notifications
  alias OliWeb.Common.FormatDateTime

  attr :system_message, :map, required: true
  attr :ctx, :map, required: true
  attr :save, :string, required: true

  def render(assigns) do
    changeset = Notifications.change_system_message(assigns.system_message)

    start_date =
      changeset
      |> Ecto.Changeset.get_field(:start)
      |> FormatDateTime.convert_datetime(assigns.ctx)

    end_date =
      changeset
      |> Ecto.Changeset.get_field(:end)
      |> FormatDateTime.convert_datetime(assigns.ctx)

    assigns =
      assign(assigns, changeset: to_form(changeset), start_date: start_date, end_date: end_date)

    ~H"""
    <.form for={@changeset} phx-submit={@save} class="d-flex align-items-center">
      <.input field={@changeset[:id]} hidden />
      <div class="flex-xl-grow-1 py-2 px-3">
        <div class="form-group">
          <.input
            type="textarea"
            field={@changeset[:message]}
            id={"system_message_message_#{@system_message.id}"}
            class="form-control"
            rows="4"
            placeholder="Type a message for all users in the system"
            maxlength="140"
          />
          <.error :for={error <- Keyword.get_values(@changeset.errors || [], :message)}>
            {translate_error(error)}
          </.error>
        </div>
      </div>
      <div class="flex-grow-1 py-2 px-3">
        <div class="form-group d-flex align-items-center">
          <label class="control-label pr-4 flex-basis-20">Start</label>
          <.input
            id="system_message_start"
            field={@changeset[:start]}
            value={@start_date}
            type="datetime-local"
            class="form-control w-75"
          />
          <.error :for={error <- Keyword.get_values(@changeset.errors || [], :start)}>
            {translate_error(error)}
          </.error>
        </div>
        <div class="form-group d-flex align-items-center">
          <label class="control-label pr-4 flex-basis-20">End</label>
          <.input
            id="system_message_end"
            field={@changeset[:end]}
            value={@end_date}
            type="datetime-local"
            class="form-control w-75"
          />
          <.error :for={error <- Keyword.get_values(@changeset.errors || [], :end)}>
            {translate_error(error)}
          </.error>
        </div>
      </div>
      <div class="flex-grow-1 py-2 px-3">
        <div class="form-check">
          <.input type="checkbox" field={@changeset[:active]} class="form-check-input" />
          <label class="form-check-label">Active</label>
        </div>
      </div>
      <div class="mb-5 flex-grow-1 py-2 px-3">
        <button class="form-button btn btn-md btn-primary btn-block mt-3" type="submit">Save</button>
        <button
          class="form-button btn btn-md btn-danger btn-block mt-3"
          phx-click="delete"
          phx-value-id={@system_message.id}
          type="button"
        >
          Delete
        </button>
      </div>
    </.form>
    """
  end
end
