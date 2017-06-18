module Editor2
  class Action
    # :add, :change, :move, :remove, :select
    attr_reader :operation
    attr_reader :target # ノードID
    attr_reader :position # 挿入位置(add, moveで使用)
    attr_reader :destination # 挿入先(moveのみで使用)
    attr_reader :payload

    def initialize(params)
      @operation = params[:operation]
      @target = params[:target]
      @position = params[:position]
      @destination = params[:destination]
      @payload = params[:payload] || {}
    end
  end
end
