defmodule NekoWeb.PageControllerTest do
  use NekoWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    document = LazyHTML.from_document(html)

    for section <-
          ~w(wedding-hero wedding-invitation wedding-schedule wedding-venue wedding-theme) do
      assert document |> LazyHTML.query("##{section}") |> Enum.count() == 1
    end

    assert document
           |> LazyHTML.query("#wedding-invitation")
           |> LazyHTML.attribute("aria-labelledby") == ["wedding-invitation-title"]

    assert document |> LazyHTML.query("#wedding-invitation-title") |> Enum.count() == 1

    assert document
           |> LazyHTML.query("#wedding-date")
           |> LazyHTML.text()
           |> String.contains?("01 · 11 · 2026")

    assert document
           |> LazyHTML.query("#wedding-invitation")
           |> LazyHTML.text()
           |> String.contains?("Passaraporn")

    assert document
           |> LazyHTML.query("#wedding-invitation")
           |> LazyHTML.text()
           |> String.contains?("Pongsatorn")

    assert document |> LazyHTML.query("[data-schedule-item]") |> Enum.count() == 5

    assert document
           |> LazyHTML.query("#wedding-countdown")
           |> LazyHTML.attribute("data-countdown") == ["2026-11-01T15:09:00+07:00"]

    background = LazyHTML.query(document, "#wedding-background")

    assert LazyHTML.attribute(background, "src") == ["/images/wedding-meadow.jpg"]

    assert background
           |> LazyHTML.attribute("class")
           |> List.first()
           |> String.contains?(
             "object-left sm:portrait:object-[18%_center] landscape:object-[42%_center]"
           )

    assert document
           |> LazyHTML.query(~s(meta[property="og:image"]))
           |> LazyHTML.attribute("content")
           |> List.first()
           |> String.ends_with?("/images/wedding-meadow.jpg")

    assert document
           |> LazyHTML.query(~s(meta[name="twitter:card"]))
           |> LazyHTML.attribute("content") == ["summary_large_image"]
  end
end
