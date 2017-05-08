defmodule MixDarkly.FeatureFlag do
  @type prerequisite :: %{
    :key => String.t(),
    :variation => integer
  }

  @type target :: %{
    :values => [String.t()],
    :variation => integer
  }

  @type weighted_variations :: %{
    :variation => integer,
    :weight => integer
  }

  @type rollout :: %{
    :variations => weighted_variations(),
    :bucket_by => String.t()
  }

  @type variation_or_rollout :: %{
    :variation => integer,
    :rollout => rollout()
  }

  @type clause :: %{
    :attribute => String.t(),
    :op => term,
    :values => [term],
    :negate => boolean
  }

  @type rule :: %{
    :variation_or_rollout => variation_or_rollout(),
    :clauses => [clause()]
  }

  @type t :: %{
    :key => String.t(),
    :version => integer,
    :on => boolean,
    :prerequisites => [prerequisite()],
    :variations => [term],
    :targets => [target()]
  }
end
