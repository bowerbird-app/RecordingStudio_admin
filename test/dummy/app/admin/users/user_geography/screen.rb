# frozen_string_literal: true

module AdminScreens
  class UserGeography < Base
    ACTION_COUNTRY_CODES = {
      "signed_in" => "US",
      "exported_report" => "GB",
      "updated_settings" => "DE",
      "invited_user" => "AU"
    }.freeze

    class << self
      def country_code_for(action)
        ACTION_COUNTRY_CODES.fetch(action.to_s, "US")
      end

      def geo_series(relation)
        grouped = relation.group(:action).count
        per_country = grouped.each_with_object(Hash.new(0)) do |(action, count), totals|
          totals[country_code_for(action)] += count
        end

        per_country.sort_by { |country_code, _count| country_code }.map do |country_code, count|
          { x: country_code, y: count }
        end
      end
    end

    key "user_geography"
    icon :globe_alt
    title "User geography"
    subtitle "See where user activity is coming from"
    query { |_context| UserActivity.all }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :status, options: -> { UserActivity.distinct.order(:status).pluck(:status) }

    summary do
      label "Total activities"
      change_good_when :up
    end
  end
end