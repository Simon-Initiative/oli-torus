defmodule OliWeb.Users.Common do
  use OliWeb, :html

  alias Oli.Accounts
  alias OliWeb.Common.Utils

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def render_email_column(
        assigns,
        %{
          email: email,
          email_confirmed_at: email_confirmed_at,
          invitation_accepted_at: invitation_accepted_at,
          locked_at: locked_at
        } = row,
        _
      ) do
    assigns =
      Map.merge(
        assigns,
        %{
          email: email,
          email_confirmed_at: email_confirmed_at,
          invitation_accepted_at: invitation_accepted_at,
          locked_at: locked_at,
          row: row
        }
      )

    checkmark =
      case assigns.row do
        %{independent_learner: false} ->
          nil

        _ ->
          cond do
            Accounts.user_confirmation_pending?(assigns.row) ->
              ~H"""
              <span
                data-bs-toggle="tooltip"
                data-bs-html="true"
                title={"Confirmation Pending sent to #{@email}"}
              >
                <i class="fas fa-paper-plane text-secondary"></i>
              </span>
              """

            not is_nil(assigns.invitation_accepted_at) ->
              ~H"""
              <span
                data-bs-toggle="tooltip"
                data-bs-html="true"
                title={"Invitation Accepted on #{Utils.render_precise_date(@row, :invitation_accepted_at, @ctx)}"}
              >
                <i class="fas fa-check text-success"></i>
              </span>
              """

            not is_nil(assigns.email_confirmed_at) ->
              ~H"""
              <span
                data-bs-toggle="tooltip"
                data-bs-html="true"
                title={"Email Confirmed on #{Utils.render_precise_date(@row, :email_confirmed_at, @ctx)}"}
              >
                <i class="fas fa-check text-success"></i>
              </span>
              """

            true ->
              ~H"""
              <span data-bs-toggle="tooltip" data-bs-html="true" title={"Invitation Pending sent to #{@email}"}>
                <i class="fas fa-paper-plane text-secondary"></i>
              </span>
              """
          end
      end

    assigns = Map.put(assigns, :checkmark, checkmark)

    ~H"""
    <div class="d-flex flex-row">
      <%= @email %>
      <div class="flex-grow-1"></div>
      <%= @checkmark %>
    </div>
    <div>
      <%= if !is_nil(@locked_at) do %>
        <span class="badge badge-warning"><i class="fas fa-user-lock"></i> Account Locked</span>
      <% end %>
    </div>
    """
  end
end
