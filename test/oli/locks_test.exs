defmodule Oli.LocksTest do
  use Oli.DataCase

  alias Oli.Authoring.Locks
  alias Oli.Publishing

  describe "locks" do

    setup do
      Seeder.base_project_with_resource2()
    end

    test "acquire/3 does acquire the lock", %{author: author, publication: publication, container_resource: container_resource } do
      assert Locks.acquire(publication.id, container_resource.id, author.id) == {:acquired}
    end

    test "acquire/3 does not acquire if already acquired", %{author: author, author2: author2, publication: publication, container_resource: container_resource} do
      assert Locks.acquire(publication.id, container_resource.id, author.id) == {:acquired}

      id = author.id

      case Locks.acquire(publication.id, container_resource.id, author2.id) do
        {:lock_not_acquired, {^id, _}} -> assert(true)
        _ -> assert(false)
      end
    end

    test "can acquire then release", %{author: author, publication: publication, container_resource: resource} do
      assert Locks.acquire(publication.id, resource.id, author.id) == {:acquired}
      assert Locks.release(publication.id, resource.id, author.id) == {:ok}
    end

    test "can only release if acquired", %{author: author, author2: author2, publication: publication, container_resource: resource} do
      assert Locks.acquire(publication.id, resource.id, author.id) == {:acquired}
      assert Locks.release(publication.id, resource.id, author2.id) == {:lock_not_held}
    end

    test "updating a lock", %{author: author, author2: author2, publication: publication, container_resource: resource} do

      assert Locks.acquire(publication.id, resource.id, author.id) == {:acquired}
      {:lock_not_acquired, {_, date1}} = Locks.acquire(publication.id, resource.id, author2.id)
      assert date1 == nil
      :timer.sleep(2000);

      assert Locks.update(publication.id, resource.id, author.id) == {:acquired}
      {:lock_not_acquired, {_, date2}} = Locks.acquire(publication.id, resource.id, author2.id)
      assert date1 != date2

      :timer.sleep(2000);
      assert Locks.update(publication.id, resource.id, author.id) == {:updated}
    end

    test "acquiring an expired lock", %{author: author, author2: author2, publication: publication, container_resource: resource} do

      # Acquire a lock
      assert Locks.acquire(publication.id, resource.id, author.id) == {:acquired}

      # Then manually set the last_updated_at time back to yesterday
      mapping = Publishing.get_resource_mapping!(publication.id, resource.id)
      Publishing.update_resource_mapping(mapping, %{lock_updated_at: yesterday() })

      # Now verify that we can acquire it via another user
      assert Locks.acquire(publication.id, resource.id, author2.id) == {:acquired}
    end


  end



end
