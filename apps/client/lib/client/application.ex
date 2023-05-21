defmodule Client.Application do
  use Application

  require Logger

  @impl true
  def start(_, _) do
    Logger.info("#{__MODULE__} starting.")

    setup_ex_ncurses()

    children = [
      Client.Connection,
      Client.Input,
      Client.Render
    ]

    options = [
      strategy: :one_for_one,
      auto_shutdown: :any_significant
    ]

    Supervisor.start_link(children, options)
  end

  @impl true
  def stop(_) do
    Logger.info("#{__MODULE__} stopping.")
    teardown_ex_ncurses()
  end

  defp setup_ex_ncurses() do
    ExNcurses.initscr()

    ExNcurses.noecho()
    ExNcurses.cbreak()
    ExNcurses.keypad()
    ExNcurses.curs_set(0)
  end

  defp teardown_ex_ncurses() do
    # ExNcurses.echo()
    ExNcurses.nocbreak()
    # ExNcurses.nokeypad()
    ExNcurses.curs_set(1)

    ExNcurses.endwin()
  end
end
