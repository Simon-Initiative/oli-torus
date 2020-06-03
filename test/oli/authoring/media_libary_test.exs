defmodule Oli.Authoring.MediaLibraryTest do

  alias Oli.Authoring.MediaLibrary
  alias Oli.Authoring.MediaLibrary.{ItemOptions}

  use Oli.DataCase

  defp media_item_fixture(project_id, tag, attrs \\ %{}) do
    Map.merge(%{
        project_id: project_id,
        url: tag,
        mime_type: tag,
        file_size: String.to_integer(tag),
        file_name: tag,
        md5_hash: tag,
        deleted: false
      },
      attrs)
    |> MediaLibrary.create_media_item()
  end

  describe "" do

    setup do
      map = Oli.Seeder.base_project_with_resource2()
      second = Oli.Seeder.another_project(Map.get(map, :author), Map.get(map, :institution))
      project1 = Map.get(map, :project)
      project2 = Map.get(second, :project)

      project_id1 = project1.id
      project_id2 = project2.id

      media_item_fixture(project_id1, "1", %{deleted: true})
      media_item_fixture(project_id1, "2")
      media_item_fixture(project_id1, "3", %{mime_type: "2"})
      media_item_fixture(project_id1, "4")
      media_item_fixture(project_id1, "5")
      media_item_fixture(project_id1, "6")
      media_item_fixture(project_id1, "7", %{file_name: "find_this_name"})
      media_item_fixture(project_id1, "8", %{file_name: "find_this_name2"})
      media_item_fixture(project_id1, "9", %{md5_hash: :crypto.hash(:md5, "identical content") |> Base.encode16()})
      media_item_fixture(project_id1, "10")

      media_item_fixture(project_id2, "11", %{deleted: true})
      media_item_fixture(project_id2, "12")
      media_item_fixture(project_id2, "13", %{mime_type: "2"})


      %{project1: project1, project2: project2}
    end

    test "size/1 returns correct size of library", %{project1: project1, project2: project2} do

      assert {:ok, 9} == MediaLibrary.size(project1.slug)
      assert {:ok, 2} == MediaLibrary.size(project2.slug)
      assert {:error, {:not_found}} == MediaLibrary.size("thisprojectdoesnotexist")

    end

    test "add/3 detects duplicate file name", %{project1: project1} do

      assert {:error, {:file_exists}} == MediaLibrary.add(project1.slug, "3", "test")
    end

    test "add/3 detects duplicate file contents", %{project1: project1} do

      {:ok, item} = MediaLibrary.add(project1.slug, "newfile", "identical content")
      assert item.file_name == "9"
    end

    test "items/2 limits and offsets correctly", %{project1: project1} do

      {:ok, {items, 9}} = MediaLibrary.items(project1.slug, %ItemOptions{limit: 2, offset: 1, order_field: "fileSize"})
      assert length(items) == 2
      assert hd(items).url == "9"

      {:ok, {items, 9}} = MediaLibrary.items(project1.slug, %ItemOptions{limit: 2, offset: 3, order_field: "fileSize"})
      assert length(items) == 2
      assert hd(items).url == "7"

      {:ok, {items, 9}} = MediaLibrary.items(project1.slug, %ItemOptions{limit: 100, offset: 3, order_field: "fileSize"})
      assert length(items) == 6
      assert hd(items).url == "7"

    end

    test "items/2 filters correctly", %{project1: project1} do

      {:ok, {items, 2}} = MediaLibrary.items(project1.slug, %ItemOptions{mime_filter: ["2"], order_field: "fileSize"})
      assert length(items) == 2

      {:ok, {items, 2}} = MediaLibrary.items(project1.slug, %ItemOptions{search_text: "this", order_field: "fileSize"})
      assert length(items) == 2

      {:ok, {items, 1}} = MediaLibrary.items(project1.slug, %ItemOptions{mime_filter: ["8"], search_text: "this", order_field: "fileSize"})
      assert length(items) == 1

    end

    test "items/2 orders correctly", %{project1: project1} do

      {:ok, {items, 9}} = MediaLibrary.items(project1.slug, %ItemOptions{order_field: "fileName", order: "asc"})
      assert hd(items).file_name == "10"

      {:ok, {items, 9}} = MediaLibrary.items(project1.slug, %ItemOptions{order_field: "fileName", order: "desc"})
      assert hd(items).file_name == "find_this_name2"

      {:ok, {items, 9}} = MediaLibrary.items(project1.slug, %ItemOptions{order_field: "mimeType", order: "asc"})
      assert hd(items).file_name == "10"

      {:ok, {items, 9}} = MediaLibrary.items(project1.slug, %ItemOptions{order_field: "mimeType", order: "desc"})
      assert hd(items).file_name == "9"

      {:ok, {items, 9}} = MediaLibrary.items(project1.slug, %ItemOptions{order_field: "dateCreated", order: "asc"})
      assert hd(items).file_name == "2"

      :timer.sleep(1000);

      media_item_fixture(project1.id, "100")

      {:ok, {items, 10}} = MediaLibrary.items(project1.slug, %ItemOptions{order_field: "dateCreated", order: "desc"})
      assert hd(items).file_name == "100"

    end

  end

end
