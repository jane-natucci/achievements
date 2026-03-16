class ChainsController < ApplicationController
  def index
    @chains = Chain.includes(:game, chain_nodes: :achievement).order(created_at: :desc)
  end

  def show
    @chain = Chain.find_by!(id: params[:id])
    @nodes = @chain.nodes_in_order
  end
end
