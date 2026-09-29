module NewsHelper
  # fenced_code_blocks/tables/strikethrough/autolink cover everything a
  # news post is likely to need; no_intra_emphasis avoids "Achievement_Chain"
  # -- style names getting misread as italics. sanitize (Rails' own
  # rails-html-sanitizer, already a dependency) strips anything Redcarpet's
  # raw-HTML passthrough would otherwise allow -- posts are admin-only now,
  # but only via this web form, not the "always trusted, console-authored"
  # assumption the old sanitize: false relied on.
  MARKDOWN = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(hard_wrap: true),
    autolink: true, fenced_code_blocks: true, strikethrough: true, tables: true, no_intra_emphasis: true
  )

  def render_news_body(body)
    sanitize(MARKDOWN.render(body.to_s))
  end
end
