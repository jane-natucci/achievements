class AddLastNewsReadAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_news_read_at, :datetime
  end
end
