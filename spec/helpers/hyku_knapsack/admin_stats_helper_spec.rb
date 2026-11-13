# frozen_string_literal: true

RSpec.describe HykuKnapsack::AdminStatsHelper, type: :helper do
  describe "#over_time" do
    it "ends the Works points on today, so the newest deposits count" do
      expect(helper.over_time[:delta_x]).to eq 30
      points = Hyrax::Statistics::Works::OverTime.new(**helper.over_time).points.to_a
      expect(points.last.first).to eq helper.over_time[:x_max].to_i * 1000
    end
  end

  describe "#collections_over_time" do
    it "ends the Collections points on today, not a step past it" do
      points = Hyrax::Statistics::Collections::OverTime.new(**helper.collections_over_time).points.to_a
      expect(points.size).to eq 13
      expect(points.last.first).to eq helper.over_time[:x_max].to_i * 1000
    end
  end
end
