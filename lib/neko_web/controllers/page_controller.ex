defmodule NekoWeb.PageController do
  use NekoWeb, :controller

  def home(conn, _params) do
    events = [
      %{
        time: "15.09",
        title: "พิธีขันหมาก",
        sub: "Khan Mak Procession",
        icon: "hero-gift",
        color: "#8fae83"
      },
      %{
        time: "15.30",
        title: "พิธีหมั้น",
        sub: "Engagement Ceremony",
        icon: "hero-heart",
        color: "#f0aebf"
      },
      %{
        time: "16.00",
        title: "พิธีรับไหว้",
        sub: "Thai Blessing Ceremony",
        icon: "hero-users",
        color: "#8fa9c2"
      },
      %{
        time: "17.00",
        title: "Vow Ceremony",
        sub: "พิธีสาบานรัก",
        icon: "hero-sparkles",
        color: "#b59ed5"
      },
      %{
        time: "18.30",
        title: "รับประทานอาหาร",
        sub: "Buffet Dinner",
        icon: "hero-cake",
        color: "#e0a876"
      }
    ]

    theme_colors = ~w(#8fa9c2 #63a092 #8fae83 #c3bfe0 #f2c3a6 #f0aebf #d5a8de #f3d56f #a9cbe8)

    render(conn, :home,
      page_title: "งานแต่งงาน Bee & Boom",
      events: events,
      theme_colors: theme_colors
    )
  end
end
