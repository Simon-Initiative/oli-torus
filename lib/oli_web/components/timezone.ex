defmodule OliWeb.Components.Timezone do
  use Phoenix.Component

  alias OliWeb.Common.{React, SessionContext}
  alias OliWeb.Router.Helpers, as: Routes

  attr(:id, :string, required: true)
  attr(:ctx, SessionContext, required: true)

  def select(assigns) do
    ~H"""
    {React.component(
      @ctx,
      "Components.SelectTimezone",
      %{
        selectedTimezone: @ctx.local_tz,
        submitAction: Routes.static_page_path(OliWeb.Endpoint, :update_timezone)
      },
      id: @id
    )}
    """
  end
end
