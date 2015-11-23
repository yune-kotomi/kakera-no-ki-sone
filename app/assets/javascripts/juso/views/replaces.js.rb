# Juso::View::Replaces
# 特定のdataスキームを付けたタグを指定のクラスで置換するユーティリティ
# - data-juso-view-class: クラス名
# - data-juso-view-name: インスタンスに付ける名前
# - data-juso-view-attributes: 初期値(JSONで投入)
# replaces = Juso::View::Replaces.new(container) # container省略時はbodyが対象
# replaces['name']
# => 指定したクラスのインスタンス

module Juso
  module View
    class Replaces
      def initialize(container = nil)
        @container = container || Element.find('body')
        @views = Hash[@container.find('[data-juso-view-class]').to_a.map do |target|
          name = target['data-juso-view-name']
          class_name = target['data-juso-view-class']
          attributes = {}
          attributes.update(JSON.parse(target['data-juso-view-attributes'])) unless target['data-juso-view-attributes'].nil?

          instruction = class_name.split('::').map{|c| ".$$scope.get('#{c}')"}.join.sub(/^\.\$/, '')
          klass = `eval(#{instruction})`

          instance = klass.new(nil, attributes)
          target.after(instance.dom_element)
          target.remove

          [name, instance]
        end]
      end

      def [](name)
        @views[name]
      end
    end
  end
end
