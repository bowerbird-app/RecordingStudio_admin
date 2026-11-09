# frozen_string_literal: true

module AdminScreens
  class ItemTypes
    chart do
      title "Items by type"
      type :bar
      series do |context|
        counts = context.query_result.relation.reorder(nil).group(:recordable_type).order(:recordable_type).count
        [ {
          name: "Items",
          data: counts.map { |type, count| { x: type, y: count } }
        } ]
      end
    end
  end
end
