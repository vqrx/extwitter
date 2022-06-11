defmodule ExTwitter.API.Auth do
  @moduledoc """
  Provides Authorization and Authentication API interfaces.
  """
  import ExTwitter.API.Base

  def request_token(redirect_url \\ nil) do
    oauth = ExTwitter.Config.get_tuples |> verify_params
    params = if redirect_url, do: [{"oauth_callback", redirect_url}], else: []
    {:ok, {{_, 200, _}, _headers, body}} =
      ExTwitter.OAuth.request(:post, request_url("oauth/request_token"),
        params, oauth[:consumer_key], oauth[:consumer_secret], "", "")

    Elixir.URI.decode_query(to_string body)
    |> Enum.map(fn {k,v} -> {String.to_atom(k), v} end)
    |> Enum.into(%{})
    |> ExTwitter.Parser.parse_request_token
  end

  def authorize_url(oauth_token, options \\ %{}) do
    args = Map.merge(%{oauth_token: oauth_token}, options)

    {:ok, request_url("oauth/authorize?" <> Elixir.URI.encode_query(args)) |> to_string}
  end

  def authenticate_url(oauth_token, options \\ %{}) do
    args = Map.merge(%{oauth_token: oauth_token}, options)

    {:ok, request_url("oauth/authenticate?" <> Elixir.URI.encode_query(args)) |> to_string}
  end

  def access_token(verifier, request_token) do
    oauth = ExTwitter.Config.get_tuples |> verify_params

    credentials = OAuther.credentials(
        consumer_key: oauth[:consumer_key],
        consumer_secret: oauth[:consumer_secret]
    )
    base_url = request_url("oauth/access_token")
    params = [{"oauth_token", request_token}, {"oauth_verifier", verifier}]
    signed_params = OAuther.sign("post", base_url, params, credentials)

    {header, req_params} = OAuther.header(signed_params)
    header = header |> Tuple.to_list() |> Enum.map(&to_charlist/1) |> List.to_tuple()
    url = base_url <> "?" <> URI.encode_query(req_params)
    request = {to_charlist(url), [header], 'application/x-www-form-urlencoded', ""}

    response = ExTwitter.OAuth.send_httpc_request(:post, request, [])
    case response do
      {:ok, {{_, 200, _}, _headers, body}} ->
        access_token = Elixir.URI.decode_query(to_string body)
        |> Enum.map(fn {k,v} -> {String.to_atom(k), v} end)
        |> Enum.into(%{})
        |> ExTwitter.Parser.parse_access_token
        {:ok, access_token}
      {:ok, res}->
        {:error, res}
    end
  end
end
