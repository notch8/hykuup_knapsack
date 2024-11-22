# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource UncaWork`
class UncaWork < Hyrax::Work
  include Hyrax::Schema(:basic_metadata)
  include Hyrax::Schema(:unca_work)
end
