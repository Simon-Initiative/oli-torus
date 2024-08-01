defmodule OliWeb.Pow.AuthorControllerCallbacks do
  @moduledoc """
  Custom module to add callbacks to the authoring pow controllers to do some light pre/post-processing of the request,
  for example, to link the just created authoring account to the user account that is currently in the conn.
  More info in https://hexdocs.pm/pow/1.0.31/README.html#phoenix-controllers
  """
  use Pow.Extension.Phoenix.ControllerCallbacks.Base
  use OliWeb, :verified_routes

  def before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, author, conn}, _config) do
    conn =
      maybe_assign_request_path(conn)

    case conn do
      %{query_params: %{"link_to_user_account?" => "true"}, assigns: %{ctx: %{user: user}}}
      when not is_nil(user) ->
        {:ok, _updated_user} = link_to_user_account(user, author.id)

        {:ok, author, conn}

      _ ->
        {:ok, author, conn}
    end
  end

  _docp = """
  If there is a "request_path" query parameter in the request, assign it to the conn.
  And since we are assigning that path to the conn, that means we are going to be redirected to that path after the action is performed.
  See OliWeb.Pow.AuthorRoutes.after_sign_in_path/1 and OliWeb.Pow.AuthorRoutes.after_registration_path/1
  """

  defp maybe_assign_request_path(
         %Plug.Conn{query_params: %{"request_path" => request_path}} = conn
       )
       when request_path not in ["", nil] do
    Plug.Conn.assign(conn, :request_path, request_path)
  end

  defp maybe_assign_request_path(conn), do: conn

  defp link_to_user_account(user_account, author_id),
    do: OliWeb.Pow.UserContext.update(user_account, %{author_id: author_id})
end
