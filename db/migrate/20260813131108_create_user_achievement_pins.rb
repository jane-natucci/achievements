class CreateUserAchievementPins < ActiveRecord::Migration[8.1]
  def change
    create_table :user_achievement_pins do |t|
      t.references :user, null: false, foreign_key: true
      t.references :achievement, null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_achievement_pins, [:user_id, :achievement_id], unique: true
  end
end
