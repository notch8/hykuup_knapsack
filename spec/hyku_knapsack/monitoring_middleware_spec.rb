# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::MonitoringMiddleware do
  let(:downstream_response) { [200, { 'Content-Type' => 'text/plain' }, ['downstream']] }
  let(:app) { ->(_env) { downstream_response } }
  let(:middleware) { described_class.new(app) }
  let(:puma_stats) do
    {
      'started_at' => '2026-07-10T00:00:00Z',
      'backlog' => 0,
      'running' => 7,
      'pool_capacity' => 5,
      'max_threads' => 7,
      'requests_count' => 12_345
    }
  end

  def request(path: described_class::PUMA_STATS_PATH, method: 'GET', query: '', headers: {})
    env = Rack::MockRequest.env_for("#{path}#{query.empty? ? '' : "?#{query}"}", method:)
    headers.each { |key, value| env[key] = value }
    middleware.call(env)
  end

  def body_json(response)
    JSON.parse(response.last.join)
  end

  def stub_env(vars)
    allow(ENV).to receive(:[]).and_call_original
    vars.each { |name, value| allow(ENV).to receive(:[]).with(name).and_return(value) }
  end

  before do
    allow(Puma).to receive(:stats_hash).and_return(puma_stats)
  end

  describe '#call' do
    context 'when the path is not the monitoring endpoint' do
      it 'passes the request through to the app' do
        expect(request(path: '/catalog')).to eq(downstream_response)
      end
    end

    context 'with a non-GET request' do
      it 'returns 405' do
        status, = response = request(method: 'POST')
        expect(status).to eq(405)
        expect(body_json(response)).to eq('error' => 'method not allowed')
      end
    end

    context 'when Puma is serving' do
      it 'returns the stats as JSON' do
        status, headers, = response = request
        expect(status).to eq(200)
        expect(headers['Content-Type']).to eq('application/json')
        expect(body_json(response)).to eq(puma_stats)
      end

      it 'sets Content-Length to the body size' do
        _, headers, body = request
        expect(headers['Content-Length']).to eq(body.join.bytesize.to_s)
      end
    end

    context 'when Puma stats are unavailable' do
      it 'returns 503 when the stats object is not registered' do
        allow(Puma).to receive(:stats_hash).and_raise(NoMethodError)
        status, = response = request
        expect(status).to eq(503)
        expect(body_json(response)).to eq('error' => 'puma stats unavailable')
      end

      it 'returns 503 when Puma does not respond to stats_hash' do
        allow(Puma).to receive(:respond_to?).and_call_original
        allow(Puma).to receive(:respond_to?).with(:stats_hash).and_return(false)
        expect(request.first).to eq(503)
      end
    end

    context 'when MONITORING_TOKEN is set' do
      before { stub_env('MONITORING_TOKEN' => 'sekret') }

      it 'returns 401 without a token' do
        status, = response = request
        expect(status).to eq(401)
        expect(body_json(response)).to eq('error' => 'unauthorized')
      end

      it 'returns 401 with a wrong token of the same length' do
        expect(request(headers: { 'HTTP_AUTHORIZATION' => 'Bearer nekret' }).first).to eq(401)
      end

      it 'returns 401 with a non-Bearer Authorization header' do
        expect(request(headers: { 'HTTP_AUTHORIZATION' => 'Basic sekret' }).first).to eq(401)
      end

      it 'accepts the correct bearer token' do
        expect(request(headers: { 'HTTP_AUTHORIZATION' => 'Bearer sekret' }).first).to eq(200)
      end

      it 'accepts the correct token query param' do
        expect(request(query: 'token=sekret').first).to eq(200)
      end
    end

    context 'when MONITORING_TOKEN is blank' do
      it 'allows access when unset' do
        stub_env('MONITORING_TOKEN' => nil)
        expect(request.first).to eq(200)
      end

      it 'allows access when empty' do
        stub_env('MONITORING_TOKEN' => '')
        expect(request.first).to eq(200)
      end
    end
  end
end
