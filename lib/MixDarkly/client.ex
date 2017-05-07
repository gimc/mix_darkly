defmodule MixDarkly.Client do

  @spec bool_variation(client :: term, key :: String.t(), user :: term , default_value :: boolean) ::
    {:ok, boolean } | :error
  def bool_variation(_client, _key, _user, default_value) do
    {:ok, default_value}
  end

end
