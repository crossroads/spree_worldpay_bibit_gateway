class AddRequiredColumnsToCheckouts < ActiveRecord::Migration
  def self.up
    add_column :checkouts, :session_id, :string
  end

  def self.down
  end
end

