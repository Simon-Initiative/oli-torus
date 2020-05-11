defmodule OliWeb.AttemptController do
  use OliWeb, :controller

  def save(conn, %{"payload" => payload}) do

    IO.inspect payload

    json conn, %{ "type" => "success"}
  end

end
