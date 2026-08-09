class SummarizeXpEvents
  Row = Struct.new(:label, :amount, keyword_init: true)

  ORDER = %w[chain_created chain_description achievement_added achievement_note].freeze

  LABELS = {
    "chain_created" => ->(_count, _unit, total) { "Chain created +#{total} xp" },
    "chain_description" => ->(_count, _unit, total) { "Chain has a description +#{total} xp" },
    "achievement_added" => lambda { |count, unit, total|
      "#{count} #{"achievement".pluralize(count)} × #{unit} xp = #{total} xp"
    },
    "achievement_note" => lambda { |count, unit, total|
      "#{count} #{"achievement".pluralize(count)} with notes × #{unit} xp = #{total} xp"
    }
  }.freeze

  def self.call(events)
    new(events).call
  end

  def initialize(events)
    @events = events
  end

  def call
    grouped = events.group_by(&:reason)

    ORDER.filter_map do |reason|
      group = grouped[reason]
      next if group.blank?

      count = group.size
      unit = group.first.amount
      total = group.sum(&:amount)

      Row.new(label: LABELS.fetch(reason).call(count, unit, total), amount: total)
    end
  end

  private

  attr_reader :events
end
