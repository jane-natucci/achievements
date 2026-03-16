class ChainEdge < ApplicationRecord
  belongs_to :chain

  belongs_to :achievement, optional: true, foreign_key: :ref_id

  belongs_to :from, class_name: "ChainNode", foreign_key: :from_node
  belongs_to :to, class_name: "ChainNode", foreign_key: :to_node
end
