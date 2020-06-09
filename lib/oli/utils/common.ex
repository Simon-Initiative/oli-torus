defmodule Oli.Utils.Common do
  def get_base_url() do
    url_config = Application.fetch_env!(:oli, OliWeb.Endpoint)[:url]

    port = case Keyword.get(url_config, :port, "80") do
      "80" -> ""
      p -> ":#{p}"
    end

    "https://#{Keyword.get(url_config, :host, "localhost")}#{port}"
  end
end
