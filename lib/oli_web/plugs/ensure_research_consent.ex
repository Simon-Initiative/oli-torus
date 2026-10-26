defmodule Oli.Plugs.EnsureResearchConsent do
  @moduledoc """
  Ensures that authenticated users have answered the research consent form when required.
  """
  use OliWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Delivery

  def init(opts), do: opts

  @doc "Redirects users with a pending section consent form before delivering content."
  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    with false <- conn.assigns[:is_admin] == true,
         true <- Delivery.user_research_consent_pending?(user, conn.assigns[:section]) do
      # Either answer completes the form; nil still needs an explicit choice.
      conn
      |> redirect(to: ~p"/research_consent?user_return_to=#{conn.request_path}")
      |> halt()
    else
      _ -> conn
    end
  end
end
