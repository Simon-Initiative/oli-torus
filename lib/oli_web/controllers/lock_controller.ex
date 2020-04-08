defmodule OliWeb.LockController do
  use OliWeb, :controller

  def acquire(conn, %{"project" => _project_slug, "resource" => _resource_slug, "user" => _user }) do
    response = %{ "type" => "success"}
    json(conn, response)
  end

  def release(conn, %{"project" => _project_slug, "resource" => _resource_slug, "user" => _user}) do
    response = %{ "type" => "success"}
    json(conn, response)
  end

end
