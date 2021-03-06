defmodule MixDarkly.Evaluation do
  alias MixDarkly.FeatureFlag
  alias MixDarkly.FeatureStore
  alias MixDarkly.User
  alias MixDarkly.Event.FeatureRequest;

  @hash_scale String.duplicate("F", 40) |> Integer.parse(16) |> elem(0)

  @type prerequisite :: %{:key => String.t(), :variation => integer }
  @type explanation :: %{:kind => String.t(), :prerequisite => prerequisite}
  @type evaluation :: %{:value => term, :explanation => String.t(), :prereq_request_events => [FeatureRequest.t()]}

  @spec evaluate_explain(flag :: FeatureFlag.t(), user :: User.t(), events :: [FeatureRequest.t()]) ::
    {:ok, evaluation :: evaluation()} |
    {:error, reason :: String.t(), explanation :: explanation(), feature_request_events :: [FeatureRequest.t()]} |
    nil
  def evaluate_explain(flag, user, events \\ [])
  def evaluate_explain(_flag, nil, _events), do: nil
  def evaluate_explain(flag, user, events) do
    case check_prerequisites(flag.prerequisites, flag, user) do
      {new_events, nil} ->
        {index, explanation} = evaluate_explain_index(flag, user)
        case FeatureFlag.get_variation(flag, index) do
          {:ok, variation} -> {:ok, %{value: variation, explanation: explanation, prereq_request_events: new_events ++ events}}
          {:error, reason} -> {:error, reason, explanation, new_events ++ events}
        end
      _ -> nil
    end
  end

  defp check_prerequisites(prerequisites, parent, user),
    do: check_prerequisites(prerequisites, parent, user, [], nil)
  defp check_prerequisites([], _parent, _user, events, last_failed_prereq),
    do: {events, last_failed_prereq}
  defp check_prerequisites([head|tail], parent, user, events, last_failed_prereq) do
    # If there is an error getting the feature flag, or the value is nil we
    # break out of the recursion by recursing on the empty list
    case FeatureStore.get(head.key) do
      {:ok, %{on: false}} ->
        check_prerequisites(tail, parent, user, events, head)
      {:ok, flag} when flag != nil ->
        new_event = %{key: flag.key, user: user, value: nil, something: nil,
                      version: flag.version, parent_key: parent.key}

        case evaluate_explain(flag, user, events) do
          {:ok, %{value: value}} when value != nil ->
            new_event = %{new_event | value: value}
            case FeatureFlag.get_variation(flag, head.variation) do
              {:ok, ^value} ->
                check_prerequisites(tail, parent, user, [new_event|events], last_failed_prereq)
              _ ->
                check_prerequisites(tail, parent, user, [new_event|events], flag)
            end
          _ ->
            check_prerequisites(tail, parent, user, [new_event|events], flag)
        end
      _ ->
        check_prerequisites([], parent, user, events, head)
    end
  end

  @spec evaluate_explain_index(feature_flag :: FeatureFlag.feature_flag(), user :: term) ::
    nil | {variation :: integer, explanation :: explanation}
  def evaluate_explain_index(feature_flag, user) do
    case find_matching_target(feature_flag, user.key) do
      nil ->
        case find_matching_rule(feature_flag, user) do
          nil ->
            case variation_index_for_user(feature_flag.fallthrough, user, feature_flag.key, feature_flag.salt) do
              nil -> nil
              variation -> {variation, %{kind: "fallthrough", variation_or_rollout: feature_flag.fallthrough}}
            end
          result -> result
        end
      target ->
        {target.variation, %{kind: "target", target: target}}
    end
  end

  @spec find_matching_target(feature_flag :: FeatureFlag.t(), key :: String.t()) ::
    FeatureFlag.target() | nil
  def find_matching_target(feature_flag, key) do
    Enum.find(feature_flag.targets, nil, fn target ->
      Enum.find(target.values, false, &(key == &1))
    end)
  end

  @spec find_matching_rule(feature_flag :: FeatureFlag.t(), user :: User.t()) ::
    {term, explanation} | nil
  def find_matching_rule(feature_flag, user) do
    rule_matches_user? = fn rule ->
      Enum.all?(rule.clauses, &(clause_matches_user?(&1, user)))
    end

    case Enum.find(feature_flag.rules, nil, rule_matches_user?) do
      nil -> nil
      rule ->
        case variation_index_for_user(rule.variation_or_rollout, user, feature_flag.key, feature_flag.salt) do
          nil -> nil
          variation -> {variation, %{kind: "rule", rule: rule}}
        end
    end
  end

  @spec clause_matches_user?(clause :: FeatureFlag.clause(), user :: User.t()) :: boolean
  def clause_matches_user?(clause, user) do
    case User.value_of(user, clause.attribute) do
      {_value, true} ->
        false
      {value, false} ->
        maybe_negate = fn x -> if clause.negate do !x else x end end
        match_fn = fn x, y -> x == y end # This needs to come from clause.op
        any_matching_clauses? = fn v -> Enum.any?(clause.values, &(match_fn.(&1, v))) end

        if is_list(value) do
          value
          |> Enum.find(false, &(any_matching_clauses?.(&1)))
          |> maybe_negate.()
        else
          value
          |> any_matching_clauses?.()
          |> maybe_negate.()
        end
    end
  end

  @spec variation_index_for_user(vr :: FeatureFlag.variation_or_rollout(), user :: User.t(), key :: String.t(), salt :: String.t()) ::
    integer | nil
  def variation_index_for_user(%{variation: nil, rollout: nil}, _user, _key, _salt), do: nil
  def variation_index_for_user(%{variation: variation}, _, _, _) when variation != nil, do: variation
  def variation_index_for_user(%{rollout: rollout}, user, key, salt) do
    bucket_by =
      if rollout.bucket_by == nil, do: "key", else: rollout.bucket_by

    bucket = bucket_user(user, key, bucket_by, salt)
    Enum.reduce_while(rollout.variations, 0, fn %{weight: weight, variation: variation}, sum ->
      if sum >= bucket,
        do: {:halt, variation},
        else: {:cont, sum + (weight / 100000.0)}
    end)
  end

  @spec bucket_user(user :: User.t(), key :: String.t(), attribute :: String.t(), salt :: String.t()) :: number
  def bucket_user(user, key, attribute, salt) do
    case User.value_of(user, attribute) do
      {_value, true} -> 0
      {value, _pass} ->
        id_hash =
          try do
            to_string(value)
          rescue
            Protocol.UndefinedError -> nil
          end

        if id_hash == nil do
          0
        else
          id_hash =
            if user.secondary != nil, do: "#{id_hash}.#{user.secondary}", else: id_hash
          hash = :crypto.hash(:sha, "#{key}.#{salt}.#{id_hash}") |> Base.encode16()
          {int_val, ""} = Integer.parse(hash, 16)
          int_val / @hash_scale
        end
    end
  end
end
