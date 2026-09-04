defmodule NekoWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use NekoWeb, :html

  embed_templates "page_html/*"

  def masked_phone(nil), do: "—"
  def masked_phone(phone), do: "••• ••• #{String.slice(phone, -4, 4)}"
end
