defmodule Oli.PredefinedTest do
  use ExUnit.Case, async: false

  alias Oli.Predefined

  test "application configuration does not contain the university directory" do
    refute :world_universities_and_domains_json in Keyword.keys(Application.get_all_env(:oli))
  end

  test "university lookup reads packaged data without a configuration payload" do
    original = Application.fetch_env(:oli, :world_universities_and_domains_json)
    Application.delete_env(:oli, :world_universities_and_domains_json)

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:oli, :world_universities_and_domains_json, value)
        :error -> Application.delete_env(:oli, :world_universities_and_domains_json)
      end
    end)

    universities = Predefined.world_universities_and_domains()

    assert length(universities) == 9_683

    assert hd(universities) == %{
             name: "Marywood University",
             country_code: "US",
             institution_url: "http://www.marywood.edu"
           }

    assert %{
             name: "Cégep de Saint-Jérôme",
             country_code: "CA",
             institution_url: "https://www.cstj.qc.ca"
           } in universities
  end
end
