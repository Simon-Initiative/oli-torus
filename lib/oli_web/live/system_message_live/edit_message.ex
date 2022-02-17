defmodule OliWeb.SystemMessageLive.EditMessage do
  use Surface.Component

  alias Oli.Notifications
  alias OliWeb.Common.FormatDateTime
  alias Surface.Components.Form

  alias Surface.Components.Form.{
    Checkbox,
    DateTimeLocalInput,
    ErrorTag,
    Field,
    HiddenInput,
    Label,
    TextArea
  }

  prop system_message, :struct, required: true
  prop timezone, :string, required: true
  prop save, :event, required: true

  def render(assigns) do
    changeset = Notifications.change_system_message(assigns.system_message)

    ~F"""
      <Form for={changeset} submit={@save} class="d-flex align-items-center">
        <HiddenInput form={:system_message} field={:id} value={@system_message.id}/>
        <div class="flex-xl-grow-1 py-2 px-3">
          <Field name={:message} class="form-group">
            <TextArea
              class="form-control"
              rows="4"
              opts={placeholder: "Type a message for all users in the system", maxlength: "140"}
            />
            <ErrorTag/>
          </Field>
        </div>
        <div class="flex-grow-1 py-2 px-3">
          <Field name={:start} class="form-group d-flex align-items-center">
            <Label class="control-label pr-4 flex-basis-20" text="Start"/>
            <DateTimeLocalInput class="form-control w-75" value={timezone_localized_datetime(Ecto.Changeset.get_field(changeset, :start), @timezone)}/>
            <ErrorTag/>
          </Field>
          <Field name={:end} class="form-group d-flex align-items-center">
            <Label class="control-label pr-4 flex-basis-20" text="End"/>
            <DateTimeLocalInput class="form-control w-75" value={timezone_localized_datetime(Ecto.Changeset.get_field(changeset, :end), @timezone)}/>
            <ErrorTag/>
          </Field>
        </div>
        <div class="flex-grow-1 py-2 px-3">
          <Field name={:active} class="form-check">
            <Checkbox class="form-check-input"/>
            <Label class="form-check-label" text="Active"/>
          </Field>
        </div>
        <div class="mb-5 flex-grow-1 py-2 px-3">
          <button class="form-button btn btn-md btn-primary btn-block mt-3" type="submit">Save</button>
          <button class="form-button btn btn-md btn-danger btn-block mt-3" :on-click="delete" phx-value-id={@system_message.id} type="button">Delete</button>
        </div>
      </Form>
    """
  end

  defp timezone_localized_datetime(nil, _timezone), do: nil

  defp timezone_localized_datetime(datetime, timezone) do
    case FormatDateTime.maybe_localized_datetime(datetime, timezone) do
      {:localized, datetime} ->
        datetime

      datetime ->
        datetime
    end
  end
end
