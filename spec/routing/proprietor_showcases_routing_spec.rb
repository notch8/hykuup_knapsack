# frozen_string_literal: true

RSpec.describe 'proprietor showcase routes', type: :routing do
  it 'answers on the admin host' do
    expect(post: "http://#{Account.admin_host}/proprietor/showcases/1/reset")
      .to route_to('proprietor/showcases#reset', id: '1', host: Account.admin_host)
  end

  it 'does not answer on a tenant host' do
    expect(post: 'http://harborview.example.com/proprietor/showcases/1/reset').not_to be_routable
  end
end
