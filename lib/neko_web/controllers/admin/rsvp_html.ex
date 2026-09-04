defmodule NekoWeb.Admin.RsvpHTML do
  use NekoWeb, :html

  embed_templates "rsvp_html/*"

  def admin_header(assigns) do
    ~H"""
    <header class="border-b border-white/10 bg-[#24313a] text-white">
      <div class="mx-auto flex max-w-7xl items-center justify-between gap-4 px-5 py-4 sm:px-8 lg:px-10">
        <a id="admin-brand" href={~p"/admin"} class="group flex min-w-0 items-center gap-3">
          <span class="grid size-10 shrink-0 place-items-center rounded-full border border-[#a9cbe8]/45 bg-white/5 font-serif text-sm tracking-[0.18em] text-[#cfe0ee] transition group-hover:bg-white/10">
            B·B
          </span>
          <span class="min-w-0">
            <span class="block text-[0.6rem] font-semibold uppercase tracking-[0.28em] text-[#a9cbe8]">
              Wedding desk
            </span>
            <span class="block truncate font-serif text-lg">Bee &amp; Boom Admin</span>
          </span>
        </a>

        <a
          id="view-wedding-site"
          href={~p"/"}
          target="_blank"
          class="inline-flex shrink-0 items-center gap-2 rounded-full border border-white/15 px-3 py-2 text-sm text-slate-200 transition hover:border-[#a9cbe8]/60 hover:bg-white/5 hover:text-white sm:px-4"
        >
          <span class="hidden sm:inline">View wedding site</span>
          <span class="sr-only sm:hidden">View wedding site</span>
          <.icon name="hero-arrow-up-right" class="size-4" />
        </a>
      </div>
    </header>
    """
  end

  def admin_footer(assigns) do
    ~H"""
    <footer class="mx-auto flex max-w-7xl items-center justify-between px-5 pb-8 text-xs text-slate-400 sm:px-8 lg:px-10">
      <span>Bee &amp; Boom · 1 November 2026</span>
      <span>Private wedding desk</span>
    </footer>
    """
  end

  def rsvp_status(%{attending: false}), do: {"Not attending", "bg-rose-50 text-rose-700"}
  def rsvp_status(_rsvp), do: {"Attending", "bg-emerald-50 text-emerald-700"}

  def party_size(%{attending: true, party_size: party_size}), do: party_size
  def party_size(_rsvp), do: 0

  def format_date(datetime), do: Calendar.strftime(datetime, "%d %b %Y · %H:%M")
end
