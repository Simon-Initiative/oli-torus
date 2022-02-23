defmodule Oli.GroupsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Groups
  alias Oli.Groups.Community

  describe "community" do
    test "create_community/1 with valid data creates a community" do
      params = params_for(:community)
      assert {:ok, %Community{} = community} = Groups.create_community(params)

      assert community.name == params.name
      assert community.description == params.description
      assert community.key_contact == params.key_contact
      assert community.global_access == params.global_access
    end

    test "create_community/1 with existing name returns error changeset" do
      insert(:community, %{name: "Testing"})

      assert {:error, %Ecto.Changeset{}} = Groups.create_community(%{name: "Testing"})
    end

    test "list_communities/0 returns ok when there are no communities" do
      assert [] = Groups.list_communities()
    end

    test "list_communities/0 returns all the communities" do
      insert_list(3, :community)

      assert 3 = length(Groups.list_communities())
    end

    test "get_community/1 returns a community when the id exists and it is active" do
      community = insert(:community)

      returned_community = Groups.get_community(community.id)

      assert community.id == returned_community.id
      assert community.name == returned_community.name
    end

    test "get_community/1 returns nil if the community does not exist" do
      assert nil == Groups.get_community(123)
    end

    test "get_community/1 returns nil if the community is not active" do
      community = insert(:community, status: :deleted)

      assert nil == Groups.get_community(community.id)
    end

    test "update_community/2 updates the community successfully" do
      community = insert(:community)

      {:ok, updated_community} = Groups.update_community(community, %{name: "new_name"})

      assert community.id == updated_community.id
      assert updated_community.name == "new_name"
    end

    test "update_community/2 does not update the community when there is an invalid field" do
      community = insert(:community)
      another_community = insert(:community)

      {:error, changeset} = Groups.update_community(community, %{name: another_community.name})
      {error, _} = changeset.errors[:name]

      refute changeset.valid?
      assert error =~ "has already been taken"
    end

    test "delete_community/1 marks the community as deleted" do
      community = insert(:community)
      assert {:ok, deleted_community} = Groups.delete_community(community)
      assert deleted_community.status == :deleted
    end

    test "change_community/1 returns a community changeset" do
      community = insert(:community)
      assert %Ecto.Changeset{} = Groups.change_community(community)
    end

    test "search_communities/1 returns all communities meeting the criteria" do
      active_communities = insert_pair(:community, status: :active)
      insert(:community, status: :deleted)

      returned_communities = Groups.search_communities(%{status: :active})

      assert length(returned_communities) == 2
      assert returned_communities == active_communities
    end
  end

  describe "community account" do
    alias Oli.Groups.CommunityAccount
    alias Oli.Accounts.{Author, User}

    test "find_or_create_community_user_account/2 finds existing account" do
      existing_account = insert(:community_user_account)

      {:ok, account} =
        Groups.find_or_create_community_user_account(
          existing_account.user_id,
          existing_account.community_id
        )

      assert account.id == existing_account.id
    end

    test "find_or_create_community_user_account/2 creates new account" do
      existing_account = insert(:community_user_account)
      community = insert(:community)

      {:ok, account} =
        Groups.find_or_create_community_user_account(
          existing_account.user_id,
          community.id
        )

      assert account.id != existing_account.id
      assert account.community_id == community.id
    end

    test "create_community_account/1 with valid data creates a community account" do
      params = params_for(:community_account)

      assert {:ok, %CommunityAccount{} = community_account} =
               Groups.create_community_account(params)

      assert community_account.author_id == params.author_id
      assert community_account.community_id == params.community_id
      assert community_account.is_admin == params.is_admin
    end

    test "create_community_account/1 for existing author and community returns error changeset" do
      author = build(:author)
      community = build(:community)
      insert(:community_admin_account, %{author: author, community: community})

      assert {:error, %Ecto.Changeset{}} =
               Groups.create_community_account(%{author: author, community: community})
    end

    test "create_community_account_from_author_email/2 with valid data creates a community account" do
      author = insert(:author)
      params = params_for(:community_account)

      assert {:ok, %CommunityAccount{} = community_account} =
               Groups.create_community_account_from_author_email(author.email, params)

      assert community_account.author_id == author.id
      assert community_account.community_id == params.community_id
      assert community_account.is_admin == params.is_admin
    end

    test "create_community_account_from_author_email/2 for non existing author email returns author not found" do
      params = params_for(:community_account)

      assert {:error, :author_not_found} =
               Groups.create_community_account_from_author_email("testing@email.com", params)
    end

    test "create_community_account_from_author_email/2 for existing author and community returns error changeset" do
      author = build(:author)
      community = build(:community)
      insert(:community_admin_account, %{author: author, community: community})

      assert {:error, %Ecto.Changeset{}} =
               Groups.create_community_account_from_author_email(author.email, %{
                 author: author,
                 community: community
               })
    end

    test "create_community_account_from_user_email/2 with valid data creates a community account" do
      user = insert(:user)
      params = params_for(:community_member_account)

      assert {:ok, %CommunityAccount{} = community_account} =
               Groups.create_community_account_from_user_email(user.email, params)

      assert community_account.user_id == user.id
      assert community_account.community_id == params.community_id
      assert community_account.is_admin == params.is_admin
    end

    test "create_community_account_from_user_email/2 for non existing user email returns author not found" do
      params = params_for(:community_account)

      assert {:error, :user_not_found} =
               Groups.create_community_account_from_user_email("testing@email.com", params)
    end

    test "create_community_account_from_user_email/2 for existing user and community returns error changeset" do
      user = build(:user)
      community = build(:community)
      insert(:community_member_account, %{user: user, community: community})

      assert {:error, %Ecto.Changeset{}} =
               Groups.create_community_account_from_user_email(user.email, %{
                 user: user,
                 community: community
               })
    end

    test "create_community_account_from_email/3 with valid data creates a community admin account" do
      author = insert(:author)
      params = params_for(:community_admin_account)

      assert {:ok, %CommunityAccount{} = community_account} =
               Groups.create_community_account_from_email("admin", author.email, params)

      assert community_account.author_id == author.id
      assert community_account.community_id == params.community_id
      assert community_account.is_admin == params.is_admin
    end

    test "create_community_account_from_email/3 with valid data creates a community member account" do
      user = insert(:user)
      params = params_for(:community_member_account)

      assert {:ok, %CommunityAccount{} = community_account} =
               Groups.create_community_account_from_email("member", user.email, params)

      assert community_account.user_id == user.id
      assert community_account.community_id == params.community_id
      assert community_account.is_admin == params.is_admin
    end

    test "create_community_accounts_from_emails/3 with valid data creates community accounts" do
      users = insert_pair(:user)
      emails = Enum.map(users, & &1.email)
      params = params_for(:community_member_account)

      assert {:ok, accounts} =
               Groups.create_community_accounts_from_emails("member", emails, params)

      assert 2 == length(accounts)

      assert accounts |> Enum.map(& &1.user_id) |> Enum.sort() ==
               users |> Enum.map(& &1.id) |> Enum.sort()

      for account <- accounts do
        assert account.community_id == params.community_id
        assert account.is_admin == params.is_admin
      end
    end

    test "create_community_accounts_from_emails/3 with partially invalid data returns error and creates valid accounts" do
      user = insert(:user)
      params = params_for(:community_member_account)

      assert {:error, :user_not_found} =
               Groups.create_community_accounts_from_emails(
                 "member",
                 [user.email, "invalid_email"],
                 params
               )

      account = Groups.get_community_account_by!(%{user_id: user.id})

      assert account.user_id == user.id
      assert account.community_id == params.community_id
      assert account.is_admin == params.is_admin
    end

    test "get_community_account/1 returns a community account when the id exists" do
      community_account = insert(:community_account)

      returned_community_account = Groups.get_community_account(community_account.id)

      assert community_account.id == returned_community_account.id
      assert community_account.author_id == returned_community_account.author_id
      assert community_account.community_id == returned_community_account.community_id
    end

    test "get_community_account/1 returns nil if the community account does not exist" do
      assert nil == Groups.get_community_account(123)
    end

    test "delete_community_account/1 deletes the community account" do
      community_account = insert(:community_account)

      assert {:ok, %CommunityAccount{}} =
               Groups.delete_community_account(%{
                 community_id: community_account.community_id,
                 author_id: community_account.author_id
               })

      refute Groups.get_community_account(community_account.id)
    end

    test "delete_community_account/1 fails when the community account does not exist" do
      community_account = insert(:community_account)

      assert {:error, :not_found} =
               Groups.delete_community_account(%{
                 community_id: 12345
               })

      assert Groups.get_community_account(community_account.id)
    end

    test "list_community_admins/1 returns the admins for a community" do
      community_account = insert(:community_admin_account)
      insert(:community_admin_account, %{community: community_account.community})
      insert(:community_member_account, %{community: community_account.community})

      admins = Groups.list_community_admins(community_account.community_id)

      assert [%Author{} | _tail] = admins
      assert 2 = length(admins)
    end

    test "list_community_members/2 returns the members for a community" do
      insert(:community_admin_account)
      %CommunityAccount{community: community} = insert(:community_member_account)
      insert(:community_member_account, %{community: community})

      members = Groups.list_community_members(community.id)

      assert [%User{} | _tail] = members
      assert 2 = length(members)

      members_limited = Groups.list_community_members(community.id, 1)
      assert [%User{}] = members_limited
    end

    test "get_community_account_by!/1 returns a community account when meets the clauses" do
      community_account = insert(:community_account)

      returned_community_account =
        Groups.get_community_account_by!(%{
          community_id: community_account.community_id,
          author_id: community_account.author_id
        })

      assert community_account.id == returned_community_account.id
      assert community_account.author_id == returned_community_account.author_id
      assert community_account.community_id == returned_community_account.community_id
    end

    test "get_community_account_by!/1 returns nil if the community account does not exist" do
      assert nil ==
               Groups.get_community_account_by!(%{
                 community_id: 1,
                 author_id: 2
               })
    end

    test "get_community_account_by!/1 returns error if more than one meets the requirements" do
      community_account = insert(:community_account)
      insert(:community_account, %{community: community_account.community})

      assert_raise Ecto.MultipleResultsError,
                   ~r/^expected at most one result but got 2 in query/,
                   fn ->
                     Groups.get_community_account_by!(%{
                       community_id: community_account.community_id
                     })
                   end
    end
  end

  describe "community visibility" do
    alias Oli.Groups.CommunityVisibility

    test "create_community_visibility/1 with valid data creates a community account" do
      params = params_for(:community_visibility)

      assert {:ok, %CommunityVisibility{} = community_visibility} =
               Groups.create_community_visibility(params)

      assert community_visibility.project_id == params.project_id
      assert community_visibility.community_id == params.community_id
    end

    test "create_community_visibility/1 for existing project and community returns error changeset" do
      project = build(:project)
      community = build(:community)
      insert(:community_visibility, %{project: project, community: community})

      assert {:error, %Ecto.Changeset{}} =
               Groups.create_community_visibility(%{project: project, community: community})
    end

    test "get_community_visibility/1 returns a community visibility when the id exists" do
      community_visibility = insert(:community_visibility)

      returned_community_visibility = Groups.get_community_visibility(community_visibility.id)

      assert community_visibility.id == returned_community_visibility.id
      assert community_visibility.project_id == returned_community_visibility.project_id
      assert community_visibility.community_id == returned_community_visibility.community_id
    end

    test "get_community_visibility/1 returns nil if the community visibility does not exist" do
      assert nil == Groups.get_community_visibility(123)
    end

    test "delete_community_visibility/1 deletes the community visibility" do
      community_visibility = insert(:community_visibility)

      assert {:ok, %CommunityVisibility{}} =
               Groups.delete_community_visibility(community_visibility.id)

      refute Groups.get_community_visibility(community_visibility.id)
    end

    test "delete_community_visibility/1 fails when the community visibility does not exist" do
      community_visibility = insert(:community_visibility)

      assert {:error, :not_found} = Groups.delete_community_visibility(12345)

      assert Groups.get_community_visibility(community_visibility.id)
    end

    test "list_community_visibilities/1 returns the communities visibilities for a community" do
      community = insert(:community)
      insert(:community_visibility, %{community: community})
      insert(:community_visibility, %{community: community})

      communities_visibilities = Groups.list_community_visibilities(community.id)

      assert [%CommunityVisibility{} | _tail] = communities_visibilities
      assert 2 = length(communities_visibilities)
    end

    test "list_community_visibilities/1 returns empty when the community doesn't have any associated" do
      community = insert(:community)

      communities_visibilities = Groups.list_community_visibilities(community.id)

      assert [] = communities_visibilities
    end
  end

  describe "community institutions" do
    alias Oli.Groups.CommunityInstitution

    test "list_community_institutions/1 returns all the institutions for a given community" do
      institution = insert(:institution)

      %CommunityInstitution{community_id: community_id} =
        insert(:community_institution, institution: institution)

      [returned_institution] = Groups.list_community_institutions(community_id)

      assert returned_institution == institution
    end

    test "create_community_institution/2 with valid data creates a community institution" do
      params = params_for(:community_institution)

      assert {:ok, %CommunityInstitution{} = community_institution} =
               Groups.create_community_institution(params)

      assert community_institution.community_id == params.community_id
      assert community_institution.institution_id == params.institution_id
    end

    test "create_community_institution/2 for existing institution and community returns error changeset" do
      institution = build(:institution)
      community = build(:community)
      insert(:community_institution, %{institution: institution, community: community})

      assert {:error, %Ecto.Changeset{}} =
               Groups.create_community_institution(%{
                 institution: institution,
                 community: community
               })
    end

    test "create_community_institution_from_institution_name/2 with valid data creates a community institution" do
      institution = insert(:institution)
      community_id = insert(:community).id

      assert {:ok, %CommunityInstitution{} = community_institution} =
               Groups.create_community_institution_from_institution_name(institution.name, %{
                 community_id: community_id
               })

      assert community_institution.community_id == community_id
      assert community_institution.institution_id == institution.id
    end

    test "create_community_institution_from_institution_name/2 with invalid data returns an error" do
      community_id = insert(:community).id

      assert {:error, :institution_not_found} ==
               Groups.create_community_institution_from_institution_name("invalid_name", %{
                 community_id: community_id
               })
    end

    test "get_community_institution_by!/1 returns a community institution when meets the clauses" do
      community_institution = insert(:community_institution)

      returned_community_institution =
        Groups.get_community_institution_by!(%{
          community_id: community_institution.community_id,
          institution_id: community_institution.institution_id
        })

      assert community_institution.id == returned_community_institution.id
      assert community_institution.community_id == returned_community_institution.community_id
      assert community_institution.institution_id == returned_community_institution.institution_id
    end

    test "get_community_institution_by!/1 returns nil if the community institution does not exist" do
      assert nil ==
               Groups.get_community_institution_by!(%{
                 community_id: 1,
                 institution_id: 2
               })
    end

    test "get_community_institution_by!/1 returns error if more than one meets the requirements" do
      community_institution = insert(:community_institution)
      insert(:community_institution, %{community: community_institution.community})

      assert_raise Ecto.MultipleResultsError,
                   ~r/^expected at most one result but got 2 in query/,
                   fn ->
                     Groups.get_community_institution_by!(%{
                       community_id: community_institution.community_id
                     })
                   end
    end

    test "delete_community_institution/1 deletes the community institution" do
      community_institution = insert(:community_institution)

      args = %{
        community_id: community_institution.community_id,
        institution_id: community_institution.institution_id
      }

      assert {:ok, %CommunityInstitution{}} = Groups.delete_community_institution(args)

      refute Groups.get_community_institution_by!(args)
    end

    test "delete_community_institution/1 fails when the community institution does not exist" do
      assert {:error, :not_found} =
               Groups.delete_community_institution(%{
                 community_id: 12345
               })
    end
  end
end
