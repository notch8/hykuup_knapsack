# frozen_string_literal: true

RSpec.describe Hyrax::FileUsageDecorator do
  let(:file_set) { valkyrie_create(:hyrax_file_set, date_uploaded: 3.days.ago) }
  let(:usage) { Hyrax::FileUsage.new(file_set.id) }

  describe '#without_analytics' do
    it 'zero-fills pageviews and downloads without querying stats' do
      expect(FileViewStat).not_to receive(:statistics)
      expect(FileDownloadStat).not_to receive(:statistics)
      usage.without_analytics
      expect(usage.total_pageviews).to eq 0
      expect(usage.total_downloads).to eq 0
    end
  end
end
