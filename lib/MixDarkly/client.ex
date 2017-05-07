defmodule MixDarkly.Client do

  @spec variation(client :: %{}, key :: String.t(), user :: %{}, default :: term) ::
    {:ok, value :: term, version :: term} |
    {:error, reason :: String.t()}
  def variation(%{:config => %{:offline => true}}, _key, _user, default), do: {:ok, default}
  def variation(_client, _key, _user, default) do
    {:ok, default}
  end

  @spec bool_variation(client :: term, key :: String.t(), user :: term , default :: boolean) ::
    {:ok, boolean } | :error
  def bool_variation(client, key, user, default) do
    case variation(client, key, user, default) do
      {:ok, value} when is_boolean(value) -> {:ok, value}
      {:ok, value} -> {:error, "Incompatible type. Expected boolean value, got #{value}"}
    end
  end

end
