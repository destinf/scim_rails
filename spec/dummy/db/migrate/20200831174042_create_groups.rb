class CreateGroups < ActiveRecord::Migration[6.0]
  def change
    create_table :groups do |t|
      t.integer "company_id"
      t.string "name", null: false

      t.timestamp :archived_at

      t.timestamps
    end
  end
end
