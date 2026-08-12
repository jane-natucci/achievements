class CommentsController < ApplicationController
  # Never constantize a polymorphic type straight from params without an
  # allowlist -- otherwise commentable_type is an arbitrary-class-lookup gadget.
  COMMENTABLE_TYPES = %w[Chain Achievement User].freeze

  before_action :require_login!

  def create
    commentable = find_commentable
    return redirect_to "/achievements/", alert: "Could not find that." unless commentable

    is_first_comment = current_user.authored_comments.none?
    comment = commentable.comments.new(comment_params.merge(user: current_user))

    if comment.save
      if is_first_comment
        AwardXp.call(user: current_user, amount: XpRules::FIRST_COMMENT_BONUS, reason: "first_comment", subject: comment)
      end
      redirect_to polymorphic_path(commentable), notice: "Comment posted."
    else
      redirect_to polymorphic_path(commentable), alert: comment.errors.full_messages.to_sentence
    end
  end

  def destroy
    comment = Comment.find_by(id: params[:id])
    return redirect_to "/achievements/", alert: "Comment not found." unless comment

    commentable = comment.commentable

    unless comment.user_id == current_user.id
      return redirect_to polymorphic_path(commentable), alert: "You can only delete your own comments."
    end

    comment.destroy!
    redirect_to polymorphic_path(commentable), notice: "Comment removed."
  end

  private

  def require_login!
    return if current_user

    redirect_to "/achievements/login/", alert: "Log in to comment."
  end

  def find_commentable
    type = params[:commentable_type]
    return unless COMMENTABLE_TYPES.include?(type)

    type.constantize.find_by(id: params[:commentable_id])
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
