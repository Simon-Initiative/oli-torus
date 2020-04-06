defmodule OliWeb.LockController do
  use OliWeb, :controller

  def acquire(conn, %{"project" => project_id, "resource" => resource_id, "user" => user_id }) do

    response = %{ "type" => "success"}
    json(conn, response)
  end

  def release(conn, %{"project" => project_id, "resource" => resource_id, "user" => user_id}) do

    response = %{ "type" => "success"}
    json(conn, response)
  end

end
