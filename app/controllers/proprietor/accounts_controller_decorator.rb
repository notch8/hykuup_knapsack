# frozen_string_literal: true

# OVERRIDE Hyku: Add part_of_consortia to permitted params
module Proprietor
  module AccountsControllerDecorator
    private

    # OVERRIDE: Add part_of_consortia and refactor to meet line length requirements
    def edit_account_params
      params.require(:account).permit(
        *permitted_scalar_params,
        **permitted_nested_params
      )
    end

    # Defines the permitted scalar attributes for an account
    # @return [Array<Symbol>]
    def permitted_scalar_params
      [
        :name, :cname, :title, :is_public, :search_only, :part_of_consortia,
        *@account.live_settings.keys
      ]
    end

    # Defines the permitted nested attributes for an account and its associations
    # @return [Hash]
    def permitted_nested_params
      {
        admin_emails: [],
        full_account_cross_searches_attributes: [:id, :_destroy, :full_account_id, { full_account_attributes: [:id] }],
        solr_endpoint_attributes: %i[id url],
        fcrepo_endpoint_attributes: %i[id url base_path],
        data_cite_endpoint_attributes: %i[mode prefix username password],
        domain_names_attributes: %i[id tenant cname is_active _destroy]
      }
    end
  end
end

Proprietor::AccountsController.prepend(Proprietor::AccountsControllerDecorator)
