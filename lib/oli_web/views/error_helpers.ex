defmodule OliWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  import OliWeb.Components.Common, only: [translate_error: 1]

  def focusHelper(form, fields, opts \\ [default: false])

  def focusHelper(form, fields, default: default) when is_list(fields) do
    Enum.any?(fields, fn field -> focusHelper(form, field, default: default) end)
  end

  def focusHelper(form, field, default: default) do
    form_has_errors = Enum.count(form.errors) > 0
    field_has_errors = hasError(form, field)

    cond do
      !form_has_errors -> default
      field_has_errors -> true
      !field_has_errors -> false
    end
  end

  def error_class(form, fields, class) when is_list(fields) do
    if Enum.any?(fields, fn field -> hasError(form, field) end), do: class, else: ""
  end

  def error_class(form, field, class) do
    if hasError(form, field), do: class, else: ""
  end

  def hasError(form, field), do: Keyword.has_key?(form.errors, field)

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field, hide_name \\ false) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      if hide_name do
        content_tag(:span, translate_error(error), class: "help-block")
      else
        content_tag(:span, humanize(field) <> " " <> translate_error(error), class: "help-block")
      end
    end)
  end

  def translate_all_changeset_errors(changeset) do
    Enum.reduce(Keyword.keys(changeset.errors), "", fn key, acc ->
      if acc == "" do
        "#{Atom.to_string(key)} #{translate_error(Keyword.get(changeset.errors, key))}"
      else
        acc <> ", #{Atom.to_string(key)} #{translate_error(Keyword.get(changeset.errors, key))}"
      end
    end)
  end
end
