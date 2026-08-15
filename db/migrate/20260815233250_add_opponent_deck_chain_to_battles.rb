class AddOpponentDeckChainToBattles < ActiveRecord::Migration[8.1]
  def change
    # Nullable -- battles created before this column existed have no
    # recorded opponent chain, and don't need a backfill (see how
    # acting_hp_after on battle_moves handles the same situation).
    add_reference :battles, :opponent_deck_chain, foreign_key: { to_table: :chains }
  end
end
