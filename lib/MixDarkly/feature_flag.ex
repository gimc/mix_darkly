defmodule MixDarkly.FeatureFlag do
  @type prerequisite :: %{
    :key => String.t(),
    :variation => integer
  }
  
  @type feature_flag :: %{
    :key => String.t(),
    :version => integer,
    :on => boolean,
    :prerequisites => [prerequisite()],
    :variations => [term]
  }
end
