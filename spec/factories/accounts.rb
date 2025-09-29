# frozen_string_literal: true

FactoryBot.define do
  factory :account_with_schema, class: 'Account' do
    name { "account#{SecureRandom.hex(4)}" }
    # Use a sequence for cname to ensure uniqueness
    sequence(:cname) { |n| "account#{n}.test.com" }

    after(:create) do |account|
      # This is the crucial part: it creates the tenant schema in the database.
      Apartment::Tenant.create(account.tenant)
    end
  end
end
