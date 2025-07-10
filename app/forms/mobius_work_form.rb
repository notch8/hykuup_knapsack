# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource MobiusWork`
#
# @see https://github.com/samvera/hyrax/wiki/Hyrax-Valkyrie-Usage-Guide#forms
# @see https://github.com/samvera/valkyrie/wiki/ChangeSets-and-Dirty-Tracking
class MobiusWorkForm < Hyrax::Forms::ResourceForm(MobiusWork)
  include Hyrax::FormFields(:basic_metadata) unless Hyrax.config.flexible?
  include Hyrax::FormFields(:mobius_work) unless Hyrax.config.flexible?
  include Hyrax::FormFields(:with_pdf_viewer) unless Hyrax.config.flexible?
  include Hyrax::FormFields(:with_video_embed) unless Hyrax.config.flexible?
  include VideoEmbedBehavior::Validation
  # Define custom form fields using the Valkyrie::ChangeSet interface
  #
  # property :my_custom_form_field

  # if you want a field in the form, but it doesn't have a directly corresponding
  # model attribute, make it virtual
  #
  # property :user_input_not_destined_for_the_model, virtual: true
end
