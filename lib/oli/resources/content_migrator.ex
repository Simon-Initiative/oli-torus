defmodule Oli.Resources.ContentMigrator do
  require Logger

  alias Oli.Utils.SchemaResolver

  # TODO: implement migration for adaptive pages when schemas are finalized.
  # For now, we skip all migrations for adaptive content
  def migrate(%{"advancedAuthoring" => true} = content, :page, to: _any) do
    content
  end

  @doc """
  Migrates a resource content model to version specified.

  resource_type can be :page or :activity. A content model is determined by it's schema under priv/schemas.
  """
  def migrate(content, :page, to: :latest) do
    if content["version"] !== SchemaResolver.get("page.schema.json").version do
      # as more content migrations are implemented, they should be added
      # sequentially to this with block so that they are all executed in order
      content
      |> migrate(:page, to: :v0_1_0)
      |> migrate(:page, to: :v0_1_1)
    else
      # content version is already up to date
      content
    end
  end

  def migrate(%{"model" => _} = content, :page, to: :v0_1_0) do
    # A migration should only execute if the version matches the expected
    # version so that the precondition is known and all migration changes
    # are deterministic. If the content version matches the expected version, we
    # allow it to run. Otherwise, we return the content as-is with a :skipped status.
    case content["version"] do
      nil ->
        # map through all model blocks searching for blocks that have a purpose set
        transformed_model =
          Enum.map(content["model"], fn block ->
            case block do
              %{"type" => type, "purpose" => purpose}
              when type == "content" or type == "activity-reference" ->
                # wrap the block in a group with the given purpose and remove the purpose from the block
                block_without_purpose = Map.delete(block, "purpose")

                if purpose == "none" do
                  block_without_purpose
                else
                  %{
                    "type" => "group",
                    "layout" => "vertical",
                    "purpose" => purpose,
                    "children" => [block_without_purpose]
                  }
                end

              _ ->
                block
            end
          end)

        migrated_content =
          %{content | "model" => transformed_model}
          |> Map.put("version", "0.1.0")

        migrated_content

      _ ->
        content
    end
  end

  def migrate(%{"model" => _} = content, :page, to: :v0_1_1) do
    case content["version"] do
      "0.1.0" ->
        # theres nothing to do, simply increment the version number
        migrated_content =
          content
          |> Map.put("version", "0.1.1")

        migrated_content

      _ ->
        content
    end
  end

  # TODO: implement migration for activities when schemas are finalized.
  def migrate(content, :activity, to: :latest) do
    # for now we just skip the migration and return content as it is
    content
  end
end
