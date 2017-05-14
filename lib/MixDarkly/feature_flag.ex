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

  defstruct key: nil,
            version: nil,
            on: true,
            prerequisites: [],
            salt: "",
            sel: "",
            targets: [],
            rules: [],
            fallthrough: nil,
            off_variation: nil,
            variations: [],
            deleted: false

  @type t :: %{
    :key => String.t(),
    :version => integer,
    :on => boolean,
    :prerequisites => [prerequisite()],
    :salt => String.t(),
    :sel => String.t(),
    :targets => [target()],
    :rules => [rule()],
    :fallthrough => variation_or_rollout(),
    :off_variation => integer,
    :variations => [term],
    :deleted => boolean
  }

  @spec get_variation(feature_flag :: FeatureFlag.t(), index :: integer) ::
    {:ok, term} |
    {:error, reason :: String.t()}
  def get_variation(_feature_flag, nil),
    do: {:error, "An index is required"}
  def get_variation(%{variations: variations}, index) when index >= length(variations),
    do: {:error, "Invalid variation index"}
  def get_variation(%{variations: variations}, index),
    do: {:ok, Enum.at(variations, index)}
end
