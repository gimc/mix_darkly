defmodule MixDarkly.Client do
  require Logger

  alias MixDarkly.FeatureFlag
  alias MixDarkly.FeatureStore
  alias MixDarkly.UpdateProcessor

  @type t :: %{
    :sdk_key => String.t(),
    :config => MixDarkly.Config.t(),
    :event_processor => pid,
    :update_processor => pid,
    :feature_store => pid
  }

  @spec variation(client :: Client.t(), key :: String.t(), user :: User.t(), default :: term) ::
    {:ok, value :: term} |
    {:error, reason :: String.t()}
  def variation(%{config: %{offline: true}}, _key, _user, default), do: {:ok, default}
  def variation(_client, _key, _user, default) do
    {:ok, default}
  end

  @spec bool_variation(client :: Client.t(), key :: String.t(), user :: User.t() , default :: boolean) ::
    {:ok, boolean } | :error
  def bool_variation(client, key, user, default) do
    case variation(client, key, user, default) do
      {:ok, value} when is_boolean(value) -> {:ok, value}
      {:ok, value} -> {:error, "Incompatible type. Expected boolean value, got #{value}"}
    end
  end

  @doc """
  Evaluates the feature flag stored under 'key' in the flag store
  """
  @spec evaluate(client :: Client.t(), key :: String.t(), user :: User.t(), default :: term) ::
    {:ok, value :: term, version :: term} |
    {:error, reason :: String.t()}
  def evaluate(_client, _key, %{key: nil}, _default), do: {:error, "User key cannot be nil"}
  def evaluate(client, key, user, default) do
    user.key == "" && Logger.warn("User key is blank")
    if client.config.offline || client.config.use_ldd || !UpdateProcessor.is_initialized?(client.update_processor) do
        {:error, "Client not initialized"}
    else
      case FeatureStore.get(client.feature_store, key) do
        {:error, _} ->
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

  @spec eval_flag(client :: Client.t(), flag :: FeatureFlag.feature_flag(), user :: User.t()) ::
    {:ok, {value :: term, pre_requisite_events :: []}} |
    {:error, {reason :: String.t(), pre_requisite_events :: []}}
  def eval_flag(client, flag, user) do
    # cond do
    #   flag.on ->
    #     {result, evaluation} = Evaluation.for_user(user, flag, client.store)
    #     cond do
    #       result == :error -> {:error, {"", evaluation.pre_requisite_events}}
    #       evaluation.value != nil -> {:ok, {evaluation.value, evaluation.pre_requisite_events}}
    #     end
    #   flag.off_variation != nil and flag.off_variation < length(flag.variations) ->
    #     {:ok, Enum.at(flag.variations, flag.off_variation), evaluation.pre_requisite_events}}
    #   true ->
    #     {:error, {"", evaluation.pre_requisite_events}}
    # end
    {:ok, {true, []}}
  end
end
