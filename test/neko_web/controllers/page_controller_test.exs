defmodule NekoWeb.PageControllerTest do
  use NekoWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    document = LazyHTML.from_document(html)

    assert document |> LazyHTML.query("#coming-soon-page") |> Enum.count() == 1
    assert document |> LazyHTML.query("#coming-soon-hero") |> Enum.count() == 1
    assert document |> LazyHTML.query("#coming-soon-notes") |> Enum.count() == 1

    assert document
           |> LazyHTML.query("#wedding-date")
           |> LazyHTML.text()
           |> String.contains?("Sunday, 01 November 2026")

    background = LazyHTML.query(document, "#coming-soon-background")

    assert LazyHTML.attribute(background, "src") == ["/images/coming-soon-meadow.jpg"]

    assert background
           |> LazyHTML.attribute("class")
           |> List.first()
           |> String.contains?("object-left sm:object-[42%_center]")
  end
end
