defmodule MixDarkly.Config do
  defstruct base_uri: "https://app.launchdarkly.com",
            stream_uri: "https://stream.launchdarkly.com",
            event_uri: "https://events.launchdarkly.com",
            capacity: 1000,
            flush_interval: 5000,
            sampling_interval: 0,
            poll_interval: 1000,
            logger: Logger,
            timeout: 3000,
            stream: true,
            feature_store: nil,
            use_ldd: false,
            send_events: true,
            offline: false

  @type config :: %MixDarkly.Config{}
end
