defmodule ExTwitter.OAuth do
  @moduledoc """
  Provide a wrapper for `:oauth` request methods.
  """

  @doc """
  Send request with get/post method.
  """
  def request(:get, url, params, consumer_key, consumer_secret, access_token, access_token_secret) do
    oauth_get(url, params, consumer_key, consumer_secret, access_token, access_token_secret, [])
  end

  def request(:post, url, params, consumer_key, consumer_secret, access_token, access_token_secret) do
    oauth_post(url, params, consumer_key, consumer_secret, access_token, access_token_secret, [])
  end

  @doc """
  Send async request with get or post method.
  """
  def request_async(:get, url, params, consumer_key, consumer_secret, access_token, access_token_secret) do
    oauth_get(url, params, consumer_key, consumer_secret, access_token, access_token_secret, stream_option())
  end

  def request_async(:post, url, params, consumer_key, consumer_secret, access_token, access_token_secret) do
    oauth_post(url, params, consumer_key, consumer_secret, access_token, access_token_secret, stream_option())
  end

  @doc """
  Send oauth request with get or post method.
  """
  def oauth_get(url, params, consumer_key, consumer_secret, access_token, access_token_secret, options) do
    signed_params = get_signed_params(
      "get", url, params, consumer_key, consumer_secret, access_token, access_token_secret)
    {header, req_params} = OAuther.header(signed_params)
    header = header |> Tuple.to_list() |> Enum.map(&to_charlist/1) |> List.to_tuple()
    encoded_params = URI.encode_query(req_params)
    request = {to_charlist(url <> "?" <> encoded_params), [header]}
    send_httpc_request(:get, request, options)
  end

  def oauth_post(url, params, consumer_key, consumer_secret, access_token, access_token_secret, options) do
    signed_params = get_signed_params(
      "post", url, [], consumer_key, consumer_secret, access_token, access_token_secret)
    {header, req_params} = OAuther.header(signed_params)
    header = header |> Tuple.to_list() |> Enum.map(&to_charlist/1) |> List.to_tuple()
    json_params = params |> Map.new() |> ExTwitter.JSON.encode!()
    request = {to_charlist(url), [header], 'application/json', json_params}
    send_httpc_request(:post, request, options)
  end

  def send_httpc_request(method, request, options) do
    :httpc.request(method, request, [{:autoredirect, false}] ++ proxy_option(), options)
  end

  defp get_signed_params(method, url, params, consumer_key, consumer_secret, access_token, access_token_secret) do
    credentials = OAuther.credentials(
        consumer_key: consumer_key,
        consumer_secret: consumer_secret,
        token: access_token,
        token_secret: access_token_secret
    )
    OAuther.sign(method, url, params, credentials)
  end

  defp stream_option do
    [{:sync, false}, {:stream, :self}]
  end

  defp proxy_option do
    ExTwitter.Proxy.options
  end
end
