# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0 (8af12cce) - advance_zero_marker compares the zero-count Date it is
# given with the marker row's `date`, an ActiveSupport::TimeWithZone, which raises
# ArgumentError. Every stats page for an object that already has a marker then 500s on
# tenants with GA configured. Remove once Hyrax compares like with like.
module Hyrax
  module StatisticZeroMarkerDecorator
    extend ActiveSupport::Concern

    class_methods do
      private

      def advance_zero_marker(object, object_method, date, user_id)
        super(object, object_method, date.in_time_zone, user_id)
      end
    end
  end
end

Hyrax::Statistic.prepend(Hyrax::StatisticZeroMarkerDecorator)
