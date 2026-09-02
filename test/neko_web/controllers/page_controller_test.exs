defmodule NekoWeb.PageControllerTest do
  use NekoWeb.ConnCase

  alias Neko.{Repo, Rsvp}

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    document = LazyHTML.from_document(html)

    for section <-
          ~w(wedding-hero wedding-invitation wedding-story wedding-schedule wedding-venue wedding-rsvp wedding-seating wedding-theme wedding-guestbook) do
      assert document |> LazyHTML.query("##{section}") |> Enum.count() == 1
    end

    assert document |> LazyHTML.query("#wedding-story-photos [data-photo-slide]") |> Enum.count() ==
             16

    assert document |> LazyHTML.query("#wedding-story-photos img") |> Enum.count() == 16

    assert document
           |> LazyHTML.query(
             ~s(#wedding-story-photos img[src="/images/bee-boom-under-the-trees.webp"])
           )
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query(
             ~s(#wedding-story-photos img[src="/images/bee-boom-pine-forest.webp"])
           )
           |> Enum.count() == 1

    assert document |> LazyHTML.query("#wedding-story-autoplay") |> Enum.count() == 1
    assert document |> LazyHTML.query("#wedding-hero[data-wedding-welcome]") |> Enum.count() == 1
    assert document |> LazyHTML.query("[data-invitation-card]") |> Enum.count() == 1

    assert document |> LazyHTML.query("#wedding-music-player") |> Enum.count() == 1
    assert document |> LazyHTML.query("#wedding-music-toggle") |> Enum.count() == 1
    assert document |> LazyHTML.query("#wedding-music[autoplay][loop]") |> Enum.count() == 1

    for status <- ~w(wedding-seating-status wedding-guestbook-status) do
      assert document
             |> LazyHTML.query("##{status}")
             |> LazyHTML.text()
             |> String.contains?("Coming Soon")
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
           |> LazyHTML.query("#wedding-venue img")
           |> LazyHTML.attribute("src") == ["/images/misstar-garden-chapel.jpg"]

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
           |> String.ends_with?("/images/bee-boom-og-v2.jpg")

    assert document
           |> LazyHTML.query(~s(meta[property="og:title"]))
           |> LazyHTML.attribute("content") == ["Bee & Boom — Our Wedding"]

    assert document |> LazyHTML.query("title") |> LazyHTML.text() |> String.trim() ==
             "Bee & Boom — Our Wedding"

    assert document
           |> LazyHTML.query(~s(meta[property="og:image:width"]))
           |> LazyHTML.attribute("content") == ["1200"]

    assert document
           |> LazyHTML.query(~s(meta[property="og:image:height"]))
           |> LazyHTML.attribute("content") == ["630"]

    assert document
           |> LazyHTML.query(~s(meta[name="twitter:card"]))
           |> LazyHTML.attribute("content") == ["summary_large_image"]

    assert document
           |> LazyHTML.query(~s(meta[name="twitter:image"]))
           |> LazyHTML.attribute("content")
           |> List.first()
           |> String.ends_with?("/images/bee-boom-og-v2.jpg")

    assert document
           |> LazyHTML.query(~s(link[rel="icon"][type="image/svg+xml"]))
           |> LazyHTML.attribute("href") == ["/images/favicon.svg"]

    assert document
           |> LazyHTML.query(~s(link[rel="apple-touch-icon"]))
           |> LazyHTML.attribute("href") == ["/images/apple-touch-icon.png"]

    assert document |> LazyHTML.query("#wedding-rsvp-form") |> Enum.count() == 1
    assert document |> LazyHTML.query("#rsvp-name") |> Enum.count() == 1
    assert document |> LazyHTML.query("#rsvp-attending") |> Enum.count() == 1
    assert document |> LazyHTML.query("#rsvp-invite-token") |> Enum.empty?()
    assert document |> LazyHTML.query("#personalized-invitation-greeting") |> Enum.empty?()
  end

  test "POST /rsvp saves an attending guest with a partner", %{conn: conn} do
    conn =
      post(conn, ~p"/rsvp", %{
        "rsvp" => %{
          "name" => "  สมชาย ใจดี  ",
          "attending" => "true",
          "bringing_partner" => "true"
        }
      })

    assert redirected_to(conn) == "/#wedding-rsvp"
    assert Phoenix.Flash.get(conn.assigns.flash, :rsvp_status) == "attending_with_partner"
    refute Phoenix.Flash.get(conn.assigns.flash, :info)

    assert %Rsvp{name: "สมชาย ใจดี", attending: true, bringing_partner: true} =
             Repo.one(Rsvp)
  end

  test "GET / replaces the form with the matching RSVP confirmation" do
    for {status, message} <- [
          {"attending", "1 ท่าน"},
          {"attending_with_partner", "รวม 2 ท่าน"},
          {"declined", "หวังว่าจะได้เจอกันในโอกาสหน้า"}
        ] do
      conn =
        build_conn()
        |> init_test_session(%{})
        |> Phoenix.Controller.fetch_flash([])
        |> Phoenix.Controller.put_flash(:rsvp_status, status)
        |> get(~p"/")

      document = conn |> html_response(200) |> LazyHTML.from_document()

      assert document |> LazyHTML.query("#rsvp-success") |> Enum.count() == 1
      assert document |> LazyHTML.query("#rsvp-success") |> LazyHTML.text() =~ message
      assert document |> LazyHTML.query("#wedding-rsvp-form") |> Enum.empty?()
    end
  end

  test "POST /rsvp clears the partner answer when the guest cannot attend", %{conn: conn} do
    conn =
      post(conn, ~p"/rsvp", %{
        "rsvp" => %{
          "name" => "สมหญิง ใจดี",
          "attending" => "false",
          "bringing_partner" => "true"
        }
      })

    assert redirected_to(conn) == "/#wedding-rsvp"
    assert Phoenix.Flash.get(conn.assigns.flash, :rsvp_status) == "declined"

    assert %Rsvp{attending: false, bringing_partner: false} = Repo.one(Rsvp)
  end

  test "POST /rsvp returns the form with errors when required answers are missing", %{conn: conn} do
    conn = post(conn, ~p"/rsvp", %{"rsvp" => %{"name" => ""}})

    assert html_response(conn, 422) =~ "wedding-rsvp-form"
    assert Repo.aggregate(Rsvp, :count) == 0
  end

  test "POST /rsvp handles malformed form submissions", %{conn: conn} do
    conn = post(conn, ~p"/rsvp", %{})

    assert html_response(conn, 422) =~ "wedding-rsvp-form"
    assert Repo.aggregate(Rsvp, :count) == 0
  end
end
