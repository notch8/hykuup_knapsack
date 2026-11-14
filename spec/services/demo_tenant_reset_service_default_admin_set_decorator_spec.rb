# frozen_string_literal: true

RSpec.describe DemoTenantResetService do
  let(:account) do
    FactoryBot.create(:demo_account, demo_tenant_snapshot: { 'site' => {}, 'content_blocks' => {} })
  end

  def admin_sets
    Hyrax.query_service.find_all_of_model(model: Hyrax.config.admin_set_class).to_a
  end

  def admin_group_manages?(admin_set)
    Hyrax::PermissionTemplate.find_by!(source_id: admin_set.id.to_s).access_grants.exists?(
      agent_type: 'group', agent_id: ::Ability.admin_group_name, access: Hyrax::PermissionTemplateAccess::MANAGE
    )
  end

  # Only the steps around the admin set run for real.
  def run_reset
    service = described_class.new(account:)
    allow(service).to receive(:within_tenant).and_yield
    %i[wipe_content! revoke_visitor_access! restore_content_blocks! restore_featured_works!].each do |step|
      allow(service).to receive(step)
    end
    service.reset!
  end

  context 'when the tenant has no admin set' do
    it 'ends with exactly one, managed by the admin group and indexed' do
      expect { run_reset }.to change { admin_sets.size }.from(0).to(1)

      admin_set = admin_sets.first
      expect(admin_group_manages?(admin_set)).to be true
      expect(Hyrax::SolrService.query("id:#{admin_set.id}", rows: 1)).to be_present
    end

    it 'creates the admin, registered and public groups it needs' do
      Hyrax::Group.where(name: %w[admin registered public]).destroy_all

      run_reset

      expect(Hyrax::Group.where(name: %w[admin registered public]).count).to eq 3
    end

    it 'does not add a second one on the next reset' do
      run_reset
      run_reset

      expect(admin_sets.size).to eq 1
    end

    it 'still creates one when the saved default id points at a deleted admin set' do
      Hyrax::DefaultAdministrativeSet.create!(default_admin_set_id: 'deleted-admin-set')

      expect { run_reset }.to change { admin_sets.size }.from(0).to(1)
    end
  end

  context 'when the tenant already has an admin set' do
    let!(:existing) { FactoryBot.valkyrie_create(:hyku_admin_set, with_permission_template: true) }

    it 'leaves it as the only one, managed by the admin group' do
      run_reset

      expect(admin_sets.map(&:id)).to eq [existing.id]
      expect(admin_group_manages?(existing)).to be true
      expect(Hyrax::SolrService.query("id:#{existing.id}", rows: 1).first['edit_access_group_ssim'])
        .to include(::Ability.admin_group_name)
    end

    it 'puts it back in Solr after the wipe' do
      Hyrax::Collections::PermissionsCreateService.add_access(
        collection_id: existing.id,
        grants: [{ agent_type: 'group', agent_id: ::Ability.admin_group_name,
                   access: Hyrax::PermissionTemplateAccess::MANAGE }]
      )
      Hyrax::SolrService.wipe!

      run_reset

      expect(Hyrax::SolrService.query("id:#{existing.id}", rows: 1)).to be_present
    end

    it 'gives it a template the admin group manages and an active workflow when it has none' do
      Hyrax::PermissionTemplate.find_by!(source_id: existing.id.to_s).destroy!

      run_reset

      expect(admin_group_manages?(existing)).to be true
      expect { Sipity::Workflow.find_active_workflow_for(admin_set_id: existing.id) }.not_to raise_error
    end

    it 'makes it the default, so the deposit form does not create another' do
      Hyrax::DefaultAdministrativeSet.create!(default_admin_set_id: 'deleted-admin-set')

      run_reset

      expect(Hyrax::DefaultAdministrativeSet.pluck(:default_admin_set_id)).to eq [existing.id.to_s]
      expect(Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id).to eq existing.id
      expect(admin_sets.size).to eq 1
    end
  end
end
