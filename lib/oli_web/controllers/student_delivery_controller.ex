defmodule OliWeb.StudentDeliveryController do
  use OliWeb, :controller
  import OliWeb.ProjectPlugs

  plug :ensure_context_id_matches

  def index(conn, %{"context_id" => context_id}) do

  end

  def page(conn, %{"context_id" => context_id, "revision_slug" => revision_slug}) do

  end


end
