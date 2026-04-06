# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AccountDecorator do
  describe 'class method .solr_collection_options' do
    subject(:options) { Account.solr_collection_options }

    context 'when SOLR_COLLECTION_REPLICAS is not set' do
      it 'defaults replication_factor to 1' do
        expect(options[:replication_factor]).to eq(1)
      end
    end

    context 'when SOLR_COLLECTION_REPLICAS is set' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('SOLR_COLLECTION_REPLICAS', 1).and_return('3')
      end

      it 'uses the environment value' do
        expect(options[:replication_factor]).to eq(3)
      end

      it 'returns an integer, not a string' do
        expect(options[:replication_factor]).to be_an(Integer)
      end
    end

    it 'preserves all other options from Hyku core' do
      expect(options).to include(:num_shards, :collection, :router)
    end

    context 'super method' do
      subject { Account.method(:solr_collection_options).super_method }

      it 'is defined in Hyku core AccountSettings' do
        expect(subject.source_location[0]).to include('account_settings.rb')
      end
    end
  end

  describe 'instance method #solr_collection_options' do
    context 'when SOLR_COLLECTION_REPLICAS is set to 3' do
      before do
        allow(Account).to receive(:solr_collection_options).and_return(
          Account.solr_collection_options.merge(replication_factor: 3)
        )
      end

      it 'stores replication_factor of 3 in account settings on creation' do
        account = Account.new
        expect(account.solr_collection_options[:replication_factor]).to eq(3)
      end
    end
    context 'when SOLR_COLLECTION_REPLICAS is not set' do
      before do
        allow(Account).to receive(:solr_collection_options).and_return(
          Account.solr_collection_options.merge(replication_factor: nil)
        )
      end
      it 'returns nil from stored settings, not the class-level default' do
        account = Account.new
        expect(account.solr_collection_options[:replication_factor]).to be_nil
      end
    end
  end
end
