defmodule OliWeb.LockController do
  use OliWeb, :controller

  def acquire(conn, %{"project" => _project_id, "resource" => _resource_id }) do

    response = %{ "type" => "success"}
    json(conn, response)
  end

  def release(conn, %{"project" => _project_id, "resource" => _resource_id}) do

    response = %{ "type" => "success"}
    json(conn, response)
  end

end
