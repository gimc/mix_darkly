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
end
