# frozen_string_literal: true
class AddPartOfConsortiaToAccounts < ActiveRecord::Migration[6.1]
  def change
    # Idempotent because apartment:migrate replays this into tenant schemas that were
    # cloned from public after the column existed but without its schema_migrations row.
    add_column :accounts, :part_of_consortia, :string, if_not_exists: true
    add_index :accounts, :part_of_consortia, if_not_exists: true
  end
end
