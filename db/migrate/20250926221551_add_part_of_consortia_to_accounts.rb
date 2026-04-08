# frozen_string_literal: true
class AddPartOfConsortiaToAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :accounts, :part_of_consortia, :string
    add_index :accounts, :part_of_consortia
  end
end
