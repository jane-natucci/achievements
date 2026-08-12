class CreateUserAchievementFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :user_achievement_favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :achievement, null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_achievement_favorites, [:user_id, :achievement_id], unique: true
  end
end
