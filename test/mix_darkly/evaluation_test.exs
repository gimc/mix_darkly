defmodule MixDarkly.EvaluationTest do
  use ExUnit.Case

  alias MixDarkly.Evaluation, as: Sut
  alias MixDarkly.FeatureFlag
  alias MixDarkly.FeatureStore
  alias MixDarkly.User

  test "clause matches user with single value" do
    clause = %{
      :attribute => "ip",
      :values => ["127.0.0.1"],
      :negate => false
    }

    user = %User{
      :ip => "127.0.0.1"
    }

    matches = Sut.clause_matches_user?(clause, user)

    assert matches == true
  end

  test "clause matches user with single negated value" do
    clause = %{
      :attribute => "ip",
      :values => ["127.0.0.1"],
      :negate => true
    }

    user = %User{
      :ip => "127.0.0.1"
    }

    matches = Sut.clause_matches_user?(clause, user)

    assert matches == false
  end

  test "clause doesn't match user with single value" do
    clause = %{
      :attribute => "ip",
      :values => ["127.0.0.1"],
      :negate => false
    }

    user = %User{
      :ip => "1.2.3.4"
    }

    matches = Sut.clause_matches_user?(clause, user)

    assert matches == false
  end

  test "find matching rule for user where no rule matches" do
    flag = %{
      rules: []
    }

    user = %User{}

    assert Sut.find_matching_rule(flag, user) == nil
  end

  test "find matching rule for user with matching variation" do
    rule = %{
      clauses: [%{
        attribute: "ip",
        values: ["127.0.0.1"],
        negate: false
      }],
      variation_or_rollout: %{variation: 1, rollout: nil}
    }

    flag = %FeatureFlag{
      variations: ["red", "green"],
      rules: [rule],
      key: "flag1",
      salt: "salty"
    }

    user = %User{
      ip: "127.0.0.1"
    }

    expected = {1, %{kind: "rule", rule: rule}}

    assert Sut.find_matching_rule(flag, user) == expected
  end

  test "successfully evaluate flag without preqrequisites" do
    flag = %{
      key: "test",
      version: 1,
      on: true,
      prerequisites: [],
      variations: ["red", "green", "blue"],
      targets: [],
      rules: [%{
        clauses: %{
          attribute: "ip", op: "eq", values: ["127.0.0.1"], negate: false
        },
        variation_or_rollout: %{
          variation: 2,
          rollout: nil
        }
      }]
    }

    user = %User{
      ip: "127.0.0.1"
    }

    feature_store = FeatureStore.start_link

    {:ok, {evaluation, _}} = Sut.evaluate_explain(flag, user, feature_store)

    assert evaluation.value == "blue"
  end

  test "rollout where user does not have value to be bucketed on" do
    user = %User{
      key: "12345",
      ip: nil
    }

    vr = %{
      rollout: %{
        bucket_by: "ip",
        variations: [
          %{variation: 0, weight: 5_000},
          %{variation: 1, weight: 95_000}
        ]
      }
    }

    index = Sut.variation_index_for_user(vr, user, "key", "salty")

    assert index == 0
  end

  test "rollout with user receiving second variation" do
    user = %User{
      key: "12345",
      ip: "127.0.0.1"
    }

    vr = %{
      rollout: %{
        bucket_by: "ip",
        variations: [
          %{variation: 0, weight: 5_000},
          %{variation: 1, weight: 95_000}
        ]
      }
    }

    index = Sut.variation_index_for_user(vr, user, "key", "salty")

    assert index == 1
  end

end
