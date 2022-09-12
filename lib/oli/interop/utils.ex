defmodule Oli.Interop.Utils do
  def prettify_error({:error, :invalid_archive}) do
    "Project archive is invalid. Archive must be a valid zip file"
  end

  def prettify_error({:error, :invalid_digest}) do
    "Project archive is invalid. Archive must include #{@project_key}.json, #{@hierarchy_key}.json and #{@media_key}.json"
  end

  def prettify_error({:error, :missing_project_title}) do
    "Project title not found in #{@project_key}.json"
  end

  def prettify_error({:error, :empty_project_title}) do
    "Project title cannot be empty in #{@project_key}.json"
  end

  def prettify_error({:error, {:invalid_idrefs, invalid_idrefs}}) do
    invalid_idrefs_str = Enum.join(invalid_idrefs, ", ")

    case Enum.count(invalid_idrefs) do
      1 ->
        "Project contains an invalid idref reference: #{invalid_idrefs_str}"

      count ->
        "Project contains #{count} invalid idref references: #{invalid_idrefs_str}"
    end
  end

  def prettify_error({:error, {:rewire_activity_references, invalid_refs}}) do
    invalid_refs_str = Enum.join(invalid_refs, ", ")

    case Enum.count(invalid_refs) do
      1 ->
        "Project contains an invalid activity reference: #{invalid_refs_str}"

      count ->
        "Project contains #{count} invalid activity references: #{invalid_refs_str}"
    end
  end

  def prettify_error({:error, {:rewire_bank_selections, invalid_refs}}) do
    invalid_refs_str = Enum.join(invalid_refs, ", ")

    case Enum.count(invalid_refs) do
      1 ->
        "Project contains an invalid activity bank selection reference: #{invalid_refs_str}"

      count ->
        "Project contains #{count} invalid activity bank selection references: #{invalid_refs_str}"
    end
  end

  def prettify_error({:error, {:invalid_json, schema, _errors, json}}) do
    "Invalid JSON found in '#{json["id"]}' according to schema #{schema.schema["$id"]}"
  end

  def prettify_error({:error, error}) do
    "An unknown error occurred: #{Kernel.to_string(error)}"
  end
end
