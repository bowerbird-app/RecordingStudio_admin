# frozen_string_literal: true

module RecordingStudioAdmin
  class SectionsController < ApplicationController
    def index
      @sections = RecordingStudioAdmin.resolve_sections(context: recording_studio_admin_context)
      @search_query = params[:q].to_s.strip
      @search_type = normalized_search_type(params[:type])
      @admin_items = recording_studio_admin_context.available_admin_items(include: %i[sections screens])
      normalized_query = @search_query.downcase
      @matching_admin_items = if @search_query.present?
                                @admin_items.select do |item|
                                  item.search_text.include?(normalized_query) && matches_search_type?(item)
                                end
                              else
                                []
                              end
      @search_result_groups = search_result_groups(@matching_admin_items)
    end

    def show
      @section = RecordingStudioAdmin.resolve_section(key: section_key, context: recording_studio_admin_context)
    end

    private

    def normalized_search_type(value)
      normalized = value.to_s.downcase
      return "sections" if normalized == "sections"
      return "screens" if normalized == "screens"

      "all"
    end

    def matches_search_type?(item)
      return true if @search_type == "all"

      item.type.to_s.pluralize == @search_type
    end

    def search_result_groups(items)
      section_lookup = @admin_items.select { |item| item.type == :section }.each_with_object({}) do |item, lookup|
        lookup[item.key.to_s] = item.title.to_s
      end

      groups = []
      section_items = items.select { |item| item.type == :section }
      groups << { title: "Sections", items: section_items } if section_items.any?

      grouped_screen_items = items.select { |item| item.type == :screen && item.parent_key.present? }
                                 .group_by { |item| item.parent_key.to_s }

      grouped_screen_items.sort_by { |parent_key, _| section_lookup[parent_key] || parent_key }.each do |parent_key, grouped_items|
        parent_title = section_lookup[parent_key] || parent_key.humanize
        groups << { title: "In #{parent_title}", items: grouped_items }
      end

      ungrouped_screens = items.select { |item| item.type == :screen && item.parent_key.blank? }
      groups << { title: "Screens", items: ungrouped_screens } if ungrouped_screens.any?
      groups
    end

    def section_key
      params[:key].presence || recording_studio_admin_context.root_admin_section_key
    end
  end
end
