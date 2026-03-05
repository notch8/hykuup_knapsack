# frozen_string_literal: true

# RoleMapper.add is not available in Hyku 7 (removed from hydra-access-controls).
# Hyrax's shared spec user factory still calls it in an after(:create) callback.
# FactoryBot.modify in hyrax-webapp adds a new callback but cannot remove the old one,
# so both run. Define the missing method as a no-op at load time so it's always present.
RoleMapper.define_singleton_method(:add) { |*args| } if defined?(RoleMapper) && !RoleMapper.respond_to?(:add)
