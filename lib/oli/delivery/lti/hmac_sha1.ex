defmodule Oli.Delivery.Lti.HmacSHA1 do

  # Some useful docs for signatures:
  # http://lti.tools/oauth/

  # Some inspiration for encoding:
  # https://github.com/lexmag/oauther/blob/master/lib/oauther.ex#L176

  @spec build_signature(
    String.t,
    String.t,
    [{String.t, String.t}],
    String.t,
    String.t | nil) :: String.t
  def build_signature(
    req_url,
    method,
    body_params,
    consumer_secret,
    token \\ ""
  ) do
    [url, query_params] = case String.split(req_url, "?") do
      [url, query_params] -> [
        # ensure the url string always ends with a slash
        (if String.ends_with?(url, "/"), do: url, else: url <> "/"),
        query_params
      ]
      [url] -> [url, ""]
    end

    [
      String.upcase(method),
      encode(url),
      process_params(
        body_params,
        params_str_to_keyword_list(query_params)
      )
    ]
    |> Enum.join("&")
    |> sign_text(encode(consumer_secret), token)
  end

  @spec sign_text(String.t, String.t) :: String.t
  def sign_text(text, secret) do
    sign_text(text, secret, "")
  end

  @spec sign_text(String.t, String.t, String.t) :: String.t
  def sign_text(text, secret, token) do
    secret = "#{secret}&#{token}"
    :crypto.hmac(:sha, secret, text) |> Base.encode64
  end

  defp params_str_to_keyword_list(str) do
    str
    |> String.split("&")
    |> Enum.map(fn param_keyval -> String.split(param_keyval, "=") end)
    |> Enum.map(fn el ->
      case el do
        [key, val] -> {key, val}
        _ -> nil
      end
    end)
    |> Enum.filter(fn el -> el != nil end)
  end

  defp process_params(body_params, query_params) do
    clean_params(body_params) ++ clean_params(query_params)
    |> Enum.sort
    |> Enum.join("&")
    |> encode
  end

  defp encode(str) do
    URI.encode(str, &URI.char_unreserved?/1)
  end

  @spec clean_params([key: String.t]) :: [String.t]
  defp clean_params(params) do
    params
    |> Enum.filter(fn {key, _val} -> key != :oauth_signature end)
    |> Enum.map(&stringify_param/1)
  end

  @spec stringify_param({String.t, String.t}) :: String.t
  defp stringify_param({key, val}) do
    "#{key}=#{encode(val)}"
  end

end
