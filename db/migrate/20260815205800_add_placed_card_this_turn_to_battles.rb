class AddPlacedCardThisTurnToBattles < ActiveRecord::Migration[8.1]
  def change
    add_column :battles, :player_placed_card_this_turn, :boolean, null: false, default: false
    add_column :battles, :opponent_placed_card_this_turn, :boolean, null: false, default: false
  end
end
