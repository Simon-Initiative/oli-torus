defmodule Oli.Plugs.EnsureResearchConsent do
  @moduledoc """
  Ensures that the authenticated user has provided research consent if required
  """
  use OliWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Delivery

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    is_admin = conn.assigns[:is_admin]

    with false <- is_admin,
         nil <- user.research_opt_out,
         true <- Delivery.user_research_consent_required?(user) do
      # User is required to provide research consent before accessing the system
      conn
      |> redirect(to: ~p"/research_consent?user_return_to=#{conn.request_path}")
      |> halt()
    else
      _ -> conn
    end
  end
end
