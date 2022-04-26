defmodule Oli.Resources.ContentMigrator do
  require Logger

  alias Oli.Utils.SchemaResolver
  alias Oli.Resources.Revision

  def migrate(%Revision{content: content} = revision, to: :latest) do
    if content["version"] !== SchemaResolver.current_version() do
      # as more content migrations are implemented, they should be added
      # sequentially to this with block so that they are all executed in order
      with {status, revision} <- migrate(revision, to: :v0_1_0) do
        {status, revision}
      end
    else
      # content version is already up to date
      {:skipped, revision}
    end
  end

  @doc """
  Initial migration that takes an un-versioned content model and migrates it to version 0.1.0
  """
  def migrate(%Revision{content: content} = revision, to: :v0_1_0) do
    previous_version = nil

    # A migration should only execute if the previous version matches the
    # expected version so that the precondition is known and all migration changes
    # are deterministic. If the current version matches the previous version, we
    # allow it to run. Otherwise, we return the revision as-is with a :skipped status.
    case content["version"] do
      ^previous_version ->
        # map through all model blocks searching for blocks that have a purpose set
        transformed_model = Enum.map(content["model"], fn block ->
          case block do
            %{"type" => type, "purpose" => purpose} when type == "content" or type == "activity-reference" ->
              # wrap the block in a group with the given purpose and remove the purpose from the block
              block_without_purpose = Map.delete(block, "purpose")

              if purpose == "none" do
                block_without_purpose
              else
                %{"type" => "group", "layout" => "vertical", "purpose" => purpose, "children" => [block_without_purpose]}
              end

            _ ->
              block
          end
        end)

        migrated_content = %{content | "model" => transformed_model}
          |> Map.put("version", "0.1.0")

        {:migrated, %Revision{revision | content: migrated_content}}

      _ ->
        {:skipped, revision}
    end
  end

end
