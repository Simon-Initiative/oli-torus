defmodule OliWeb.AuthView do
  use OliWeb, :view

  def has_validation_error(name) do
    @validation_errors && Map.has_key?(@validation_errors, name)
  end

  def get_validation_error(name) do
    @validation_errors[name]
  end
end
