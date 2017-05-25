defmodule MixDarkly.Client do
  require Logger

  alias MixDarkly.Config
  alias MixDarkly.Evaluation
  alias MixDarkly.EventProcessor
  alias MixDarkly.FeatureFlag
  alias MixDarkly.FeatureStore
  alias MixDarkly.UpdateProcessor
  alias MixDarkly.Event.FeatureRequest, as: FeatureRequestEvent

  @spec variation(config :: Config.t(), key :: String.t(), user :: User.t(), default :: term) ::
    {:ok, value :: term}
  def variation(%{offline: true}, _key, _user, default), do: {:ok, default}
  def variation(client, key, user, default) do
    case evaluate(client, key, user, default) do
      {:ok, value, _version} -> {:ok, value}
      {:error, _reason} -> {:ok, default}
    end
  end

  @spec bool_variation(config :: Config.t(), key :: String.t(), user :: User.t() , default :: boolean) ::
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
  @spec evaluate(config :: Config.t(), key :: String.t(), user :: User.t(), default :: term) ::
    {:ok, value :: term, version :: term} |
    {:error, reason :: String.t()}
  def evaluate(_config, _key, %{key: nil}, _default), do: {:error, "User key cannot be nil"}
  def evaluate(%{offline: true}, _, _, _), do: {:error, "Client not initialized"}
  def evaluate(%{use_ldd: true}, _, _, _), do: {:error, "Client not initialized"}
  def evaluate(_config, key, user, default) do
    user.key == "" && Logger.warn("User key is blank")
    case FeatureStore.get(key) do
      {:error, _} ->
        {:error, "Could not find key: #{key}"}
      {:ok, feature_flag} ->
        {result, {value, events}} = eval_flag(feature_flag, user)
        Enum.each(events, &EventProcessor.send/1)
        if result == :ok do
          {:ok, value, feature_flag.version}
        else
          {:ok, default, feature_flag.version}
        end
    end
  end

  @spec eval_flag(flag :: FeatureFlag.t(), user :: User.t()) ::
    {:ok, {value :: term, pre_requisite_events :: [FeatureRequestEvent.t()]}}
  defp eval_flag(%{on: true} = flag, user) do
    {result, evaluation} = Evaluation.evaluate_explain(flag, user)
    cond do
      result == :error -> {:ok, {nil, evaluation.prereq_request_events}}
      evaluation.value != nil -> {:ok, {evaluation.value, evaluation.prereq_request_events}}
      true -> {:ok, {evaluate_off_variation(flag), evaluation.prereq_request_events}}
    end
  end
  defp eval_flag(flag, _user), do: {:ok, {evaluate_off_variation(flag), []}}

  defp evaluate_off_variation(%{off_variation: nil}), do: nil
  defp evaluate_off_variation(%{off_variation: off_variation, variations: variations})
    when off_variation >= length(variations), do: nil
  defp evaluate_off_variation(flag), do: Enum.at(flag.variations, flag.off_variation)
end
