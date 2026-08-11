module ApplicationHelper
  GITHUB_REPOSITORY_URL = "https://github.com/jane-natucci/achievements"

  def build_commit_sha
    @build_commit_sha ||= begin
      sha = ENV["GIT_COMMIT_SHA"]
      sha ||= local_git_commit_sha unless Rails.env.production?
      sha = sha.to_s.strip
      sha.match?(/\A[0-9a-f]{7,40}\z/i) ? sha : nil
    end
  end

  def build_commit_short_sha
    build_commit_sha&.first(7)
  end

  def build_commit_url
    "#{GITHUB_REPOSITORY_URL}/commit/#{build_commit_sha}" if build_commit_sha.present?
  end

  def page_title(default)
    title = content_for(:title).presence || default
    Rails.env.development? ? "#{title} (local)" : title
  end

  private

  def local_git_commit_sha
    head_path = Rails.root.join(".git", "HEAD")
    return unless head_path.file?

    head = head_path.read.strip
    return head unless head.start_with?("ref: ")

    ref_path = Rails.root.join(".git", head.delete_prefix("ref: "))
    ref_path.read.strip if ref_path.file?
  rescue Errno::ENOENT, Errno::EACCES
    nil
  end
end
