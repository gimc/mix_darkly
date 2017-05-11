defmodule MixDarkly.EvaluationTest do
  use ExUnit.Case

  alias MixDarkly.Evaluation, as: Sut
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

  test "successfully evaluate flag without preqrequisites" do
    flag = %{
      :key => "test",
      :version => 1,
      :on => true,
      :prerequisites => [],
      :variations => ["red", "green", "blue"],
      :rules => [%{
        :clauses => %{
          :attribute => "ip", :values => ["127.0.0.1"], :negate => false
        }
      }]
    }

    user = %User{
      :ip => "127.0.0.1"
    }

    feature_store = FeatureStore.start_link

    {:ok, {evaluation, _}} = Evaluation.evaluate_explain(flag, user, feature_store)
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
