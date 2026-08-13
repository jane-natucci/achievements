class CreateUserAchievementUnlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :user_achievement_unlocks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :achievement, null: false, foreign_key: true
      t.datetime :unlocked_at
      t.string :source

      t.timestamps
    end

    add_index :user_achievement_unlocks, [:user_id, :achievement_id], unique: true
  end
end
