defmodule MixDarkly.Client do
  require Logger

  alias MixDarkly.FeatureFlag
  alias MixDarkly.FeatureStore
  alias MixDarkly.UpdateProcessor

  @type client :: %{
    :sdk_key => String.t(),
    :config => MixDarkly.Config.config(),
    :event_processor => pid,
    :update_processor => pid,
    :feature_store => pid
  }

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
      {:error, _reason} -> {:ok, default}
    end
  end

  @doc """
  Evaluates the feature flag stored under 'key' in the flag store
  """
  @spec evaluate(client :: term, key :: String.t(), user :: term, default :: term) ::
    {:ok, value :: term, version :: term} |
    {:error, reason :: String.t()}
  def evaluate(_client, _key, %{:key => nil}, _default), do: {:error, "User key cannot be nil"}
  def evaluate(client, key, user, default) do
    user.key == "" && Logger.warn("User key is blank")
    if client.config.offline || client.config.use_ldd || !UpdateProcessor.is_initialized?(client.update_processor) do
        {:error, "Client not initialized"}
    else
      case FeatureStore.get(client.feature_store, key) do
        :error ->
          {:error, "Could not find key: #{key}"}
        {:ok, feature_flag} ->
          {result, {value, _events}} = eval_flag(client, feature_flag, user)
          #Enum.for_each(events, &(EventProcessor.send(client.event_processor, &1)))
          if result == :ok do
            {:ok, value, feature_flag.version}
          else
            {:ok, default, feature_flag.version}
          end
      end
    end
  end

  @spec eval_flag(client :: client(), flag :: FeatureFlag.feature_flag(), user :: term) ::
    {:ok, {value :: term, pre_requisite_events :: []}} |
    {:error, {reason :: String.t(), pre_requisite_events :: []}}
  defp eval_flag(_client, _flag, _user) do
    {:ok, {true, []}}
  end
end
