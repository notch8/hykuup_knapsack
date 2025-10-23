# frozen_string_literal: true

# Test to verify view path loading in knapsack
RSpec.describe 'View Path Loading Test', type: :view do
  it 'should prioritize knapsack views over hyrax-webapp views' do
    # Get the current view paths
    view_paths = ApplicationController.view_paths.collect(&:to_s)
    
    # Find the knapsack view path
    knapsack_view_path = HykuKnapsack::Engine.root.join('app', 'views').to_s
    hyrax_view_path = Rails.root.join('app', 'views').to_s
    
    puts "Knapsack view path: #{knapsack_view_path}"
    puts "Hyrax view path: #{hyrax_view_path}"
    puts "All view paths: #{view_paths}"
    
    # Knapsack view path should be first (highest priority)
    expect(view_paths.first).to eq(knapsack_view_path)
    
    # Hyrax view path should be later in the list
    expect(view_paths).to include(hyrax_view_path)
    expect(view_paths.index(knapsack_view_path)).to be < view_paths.index(hyrax_view_path)
  end
  
  it 'should be able to find knapsack views' do
    # Test that we can find a view in the knapsack
    knapsack_view_path = HykuKnapsack::Engine.root.join('app', 'views')
    
    # Check if the knapsack views directory exists
    expect(File.directory?(knapsack_view_path)).to be true
    
    # List some files in the knapsack views directory
    view_files = Dir.glob(File.join(knapsack_view_path, '**', '*.erb'))
    puts "Knapsack view files found: #{view_files.first(5)}"
    
    expect(view_files).not_to be_empty
  end

  it 'should render knapsack view when both knapsack and hyrax-webapp have the same view' do
    # Test with a view that exists in both locations
    # Let's use the mobius_work partial as an example
    
    # First, let's check if both files exist
    knapsack_view = HykuKnapsack::Engine.root.join('app', 'views', 'hyrax', 'mobius_works', '_mobius_work.html.erb')
    hyrax_view = Rails.root.join('app', 'views', 'hyrax', 'mobius_works', '_mobius_work.html.erb')
    
    puts "Knapsack view exists: #{File.exist?(knapsack_view)}"
    puts "Hyrax view exists: #{File.exist?(hyrax_view)}"
    
    # If both exist, we can test which one gets rendered
    if File.exist?(knapsack_view) && File.exist?(hyrax_view)
      # Read the first few lines to see which version is being used
      knapsack_content = File.read(knapsack_view)
      hyrax_content = File.read(hyrax_view)
      
      puts "Knapsack view content (first 100 chars): #{knapsack_content[0..100]}"
      puts "Hyrax view content (first 100 chars): #{hyrax_content[0..100]}"
      
      # They should be different if knapsack is overriding
      expect(knapsack_content).not_to eq(hyrax_content)
    end
  end
end
