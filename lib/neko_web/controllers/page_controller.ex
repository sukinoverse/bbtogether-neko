defmodule NekoWeb.PageController do
  use NekoWeb, :controller

  def home(conn, _params) do
    render(conn, :home, page_title: "Bee & Boom")
  end
end
