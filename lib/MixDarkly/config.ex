defmodule MixDarkly.Config do
  defstruct sdk_key: "",
            base_uri: "https://app.launchdarkly.com",
            stream_uri: "https://stream.launchdarkly.com",
            capacity: 1000,
            sampling_interval: 0,
            poll_interval: 1000,
            logger: Logger,
            timeout: 3000,
            stream: true,
            feature_store: nil,
            use_ldd: false,
            send_events: true,
            offline: false,
            event_processor_config: %MixDarkly.EventProcessor.Config{}

  @type t :: %MixDarkly.Config{}
end
