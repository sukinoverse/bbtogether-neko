defmodule NekoWeb.PageController do
  use NekoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
