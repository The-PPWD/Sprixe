defmodule Server.Application do
  use Application

  @impl true
  def start(_, _) do
    children = [
      Server.Connection,
      {Registry, keys: :unique, name: Server.PlayerRegistry},
      Server.PlayerSupervisor
    ]

    options = [strategy: :one_for_one]
    Supervisor.start_link(children, options)
  end
end
