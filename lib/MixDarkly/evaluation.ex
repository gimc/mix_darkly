defmodule MixDarkly.Evaluation do
  alias MixDarkly.FeatureFlag
  alias MixDarkly.User

  @type prerequisite :: %{:key => String.t(), :variation => integer }
  @type explanation :: %{:kind => String.t(), :prerequisite => prerequisite}
  @type evaluation :: %{:value => term, :explanation => String.t(), :prerequisite_request_events => [prerequisite]}

  @spec for_user(user :: User.t(), flag :: FeatureFlag.t(), feature_store :: pid) ::
    {:ok, {evaluation :: evaluation(), [prerequisite()]}} |
    {:error, explanation :: explanation()}
  def for_user(user, flag, _feature_store) when user == nil, do: nil
  def for_user(user, flag, feature_store) do

    # For each prerequisite...
    ## Does it exist in the store? If not, it is a failure
    ## Is it on? If not it is a failure
    ## Otherwise, evaluate it
    ### If the evaluation errors, it is a failure but processing continues
    ### Append a new feature request event for this prereq
    ### Get the prereq feature's variation value and check it against the required value, if they don't match then this is a failure

    # After processing each prerequisite
    # If there is a failed prereq set, return a failed evaluation with an explanation
    # 'evaluateExplainIndex', whatever that is
    # Get the variation for the feature flag, if there is an error return it
    # Otherwise return the successful variation + explanation

    {:ok,
     %{:value => "foo", :explanation => "rule", :prerequisite_request_events => []},
     []}
  end

  @spec process_prerequisites(flag, user, feature_store) :: {good :: [], bad :: []}
  defp process_prerequisites(flag, user, feature_store) do
    {[], []}
  end

  @spec evaluate_explain_index(feature_flag :: FeatureFlag.feature_flag(), user :: term) ::
    nil | {variation :: term, explanation :: explanation}
  def evaluate_explain_index(feature_flag, user) do
    nil
  end

  @spec find_matching_target(feature_flag :: FeatureFlag.t(), key :: String.t()) :: String.t()
  def find_matching_target(feature_flag, key) do
    feature_flag[:targets]
    |> Enum.find(fn target ->
      Enum.find(target[:values], &(key == &1))
    end)
  end

  @spec rule_matches_user?(rule :: FeatureFlag.rule(), user :: User.t()) :: boolean
  def rule_matches_user?(rule, user) do
    Enum.all?(rule.clauses, &(clause_matches_user?(&1, user)))
  end

  @spec clause_matches_user?(clause :: FeatureFlag.clause(), user :: User.t()) :: boolean
  def clause_matches_user?(clause, user) do
    case User.value_of(user, clause.attribute) do
      {value, true} ->
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
end
