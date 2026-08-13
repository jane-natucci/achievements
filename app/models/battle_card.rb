class BattleCard < ApplicationRecord
  SLOTS = %w[left center right].freeze

  belongs_to :battle
  belongs_to :achievement

  def alive?
    zone != "dead"
  end

  def in_play?
    %w[hand board].include?(zone)
  end
end
