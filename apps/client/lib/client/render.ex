defmodule Client.Render do
  use GenServer

  def start_link(_) do
    options = [name: __MODULE__]
    GenServer.start_link(__MODULE__, [], options)
  end

  def render(states) do
    GenServer.cast(__MODULE__, {:render, states})
  end

  def update_state(states) do
    GenServer.cast(__MODULE__, {:update_state, states})
  end

  def init(_) do
    {:ok, []}
  end

  def handle_call(_msg, _from, states) do
    {:reply, :ok, states}
  end

  def handle_cast({:render, new_states}, _) do
    ExNcurses.clear()
    render_player_states(new_states)
    {:noreply, new_states}
  end

  def handle_cast({:update_state, new_states}, _) do
    Client.Render.render(new_states)
    {:noreply, new_states}
  end

  # test
  defp render_player_states([]) do
    ExNcurses.refresh()
  end

  defp render_player_states([%{y: y, x: x} | player_states]) do
    ExNcurses.mvaddstr(y, x, "x")
    render_player_states(player_states)
  end
end
