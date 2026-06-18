# frozen_string_literal: true

require "test_helper"

class FlatPackGeoChartSupportTest < Minitest::Test
  def test_apex_chart_type_and_default_options_for_geo_widgets
    component_class = Class.new do
      def initialize(type)
        @type = type
      end

      def validate_type!
        :validated
      end

      def apex_chart_type
        :line
      end

      def default_options
        {
          chart: { toolbar: { show: true } },
          markers: { size: 2 }
        }
      end
    end
    component_class.prepend(RecordingStudioAdmin::FlatPackGeoChartSupport)

    geo_component = component_class.new(:geo)
    line_component = component_class.new(:line)

    assert_nil geo_component.validate_type!
    assert_equal :validated, line_component.validate_type!
    assert_equal :scatter, geo_component.apex_chart_type
    assert_equal :line, line_component.apex_chart_type

    geo_options = geo_component.default_options
    line_options = line_component.default_options

    assert_equal false, geo_options.dig(:chart, :toolbar, :show)
    assert_equal false, geo_options.dig(:chart, :zoom, :enabled)
    assert_equal 8, geo_options.dig(:markers, :size)
    assert_equal 2, line_options.dig(:markers, :size)
  end

  def test_install_prepends_support_only_once_when_flatpack_component_exists
    previous_flat_pack = Object.const_get(:FlatPack) if Object.const_defined?(:FlatPack)
    Object.send(:remove_const, :FlatPack) if Object.const_defined?(:FlatPack)

    flat_pack_module = Module.new
    chart_module = Module.new
    component_class = Class.new
    chart_module.const_set(:Component, component_class)
    flat_pack_module.const_set(:Chart, chart_module)
    Object.const_set(:FlatPack, flat_pack_module)

    RecordingStudioAdmin::FlatPackGeoChartSupport.install!
    first_count = component_class.ancestors.count(RecordingStudioAdmin::FlatPackGeoChartSupport)

    RecordingStudioAdmin::FlatPackGeoChartSupport.install!
    second_count = component_class.ancestors.count(RecordingStudioAdmin::FlatPackGeoChartSupport)

    assert_equal 1, first_count
    assert_equal 1, second_count
  ensure
    Object.send(:remove_const, :FlatPack) if Object.const_defined?(:FlatPack)
    Object.const_set(:FlatPack, previous_flat_pack) if previous_flat_pack
  end

  def test_install_is_no_op_when_flatpack_component_is_missing
    previous_flat_pack = Object.const_get(:FlatPack) if Object.const_defined?(:FlatPack)
    Object.send(:remove_const, :FlatPack) if Object.const_defined?(:FlatPack)

    RecordingStudioAdmin::FlatPackGeoChartSupport.install!

    assert true
  ensure
    Object.const_set(:FlatPack, previous_flat_pack) if previous_flat_pack
  end
end