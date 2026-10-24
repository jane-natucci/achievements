# robots.txt and sitemap.xml. The app answers on achievements.jane.berlin and, under its old name, on
# achievementchai.nz; every address it gives out belongs to achievements.jane.berlin (see ApplicationHelper#site_url),
# so the same page is never indexed twice.
#
# Half a million achievements are stored (every Steam game's), so the sitemap lists only what the site is about:
# the chains people built, the achievements inside them, the news, and the few static pages. Players' own pages
# (profiles, walls) are marked noindex and left out.
class SeoController < ApplicationController
  def robots
    expires_in 1.hour, public: true
    render plain: <<~TXT
      User-agent: *
      Allow: /
      # The onboarding wizard, battles and the ops screens: nothing for a crawler to index. (Players' own pages and
      # the sign-in page are not listed here on purpose: they say noindex themselves, and a crawler can only see that
      # if it is allowed to read them.)
      Disallow: /wizard
      Disallow: /battles
      Disallow: /debug
      Disallow: /sidekiq

      Sitemap: #{helpers.site_url}/sitemap.xml
    TXT
  end

  def sitemap
    expires_in 1.hour, public: true
    chains = Chain.kept.order(:id).select(:id, :updated_at)
    achievements = Achievement.where(id: ChainNode.where(chain_id: chains.map(&:id)).select(:ref_id)).order(:id).select(:id, :updated_at)
    posts = NewsPost.published.select(:id, :published_at, :updated_at)

    base = helpers.site_url
    @entries = [ [ "#{base}/", chains.map(&:updated_at).max, "1.0" ], [ "#{base}/chains", chains.map(&:updated_at).max, "0.9" ],
                 [ "#{base}/welcome", nil, "0.5" ], [ "#{base}/help", nil, "0.4" ], [ "#{base}/news", posts.first&.published_at, "0.5" ] ]
    @entries += chains.map { |c| [ "#{base}/chains/#{c.id}", c.updated_at, "0.8" ] }
    @entries += achievements.map { |a| [ "#{base}/achievements/#{a.id}", a.updated_at, "0.6" ] }
    @entries += posts.map { |p| [ "#{base}/news/#{p.id}", p.updated_at, "0.5" ] }
    render formats: :xml
  end
end
