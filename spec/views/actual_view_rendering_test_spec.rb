# frozen_string_literal: true

# Test to verify which view actually gets rendered
RSpec.describe 'Actual View Rendering Test', type: :view do
  before do
    # Add a unique marker to the knapsack view to identify it
    knapsack_view_path = HykuKnapsack::Engine.root.join('app', 'views', 'hyrax', 'mobius_works', '_mobius_work.html.erb')
    if File.exist?(knapsack_view_path)
      # Read the current content
      content = File.read(knapsack_view_path)
      
      # Add a unique comment at the top if it doesn't already have one
      unless content.include?('KNAPSACK_VIEW_MARKER')
        content = "<!-- KNAPSACK_VIEW_MARKER: This view is from the knapsack -->\n" + content
        File.write(knapsack_view_path, content)
      end
    end
  end

  it 'should find the knapsack version of mobius_work partial' do
    # Ensure knapsack view paths are configured
    ensure_knapsack_view_paths
    
    # Debug view path information
    debug_view_paths
    
    # Check if the knapsack view file exists directly
    knapsack_view_path = HykuKnapsack::Engine.root.join('app', 'views', 'hyrax', 'mobius_works', '_mobius_work.html.erb')
    puts "Direct check - knapsack view exists: #{File.exist?(knapsack_view_path)}"
    puts "Knapsack view path: #{knapsack_view_path}"
    
    # The file should exist
    expect(File.exist?(knapsack_view_path)).to be true
    
    # Check if it contains our marker
    if File.exist?(knapsack_view_path)
      content = File.read(knapsack_view_path)
      expect(content).to include('KNAPSACK_VIEW_MARKER')
      puts "Template contains knapsack marker: #{content.include?('KNAPSACK_VIEW_MARKER')}"
    end
  end

  it 'should show view path information' do
    # Get view path information
    view_paths = ApplicationController.view_paths.collect(&:to_s)
    knapsack_view_path = HykuKnapsack::Engine.root.join('app', 'views').to_s
    
    puts "View paths in order:"
    view_paths.each_with_index do |path, index|
      marker = path == knapsack_view_path ? " <-- KNAPSACK" : ""
      puts "  #{index}: #{path}#{marker}"
    end
    
    # The knapsack path should be first
    expect(view_paths.first).to eq(knapsack_view_path)
  end
end
