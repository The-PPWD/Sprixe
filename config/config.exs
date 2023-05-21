import Config

config :logger,
       backends: [{LoggerFileBackend, :sprixe}]

config :logger, :sprixe,
       level: :all,
       metadata: [:frame_count],
       path: "sprixe.log"
