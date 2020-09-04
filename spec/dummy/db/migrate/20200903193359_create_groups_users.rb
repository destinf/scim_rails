class CreateGroupsUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :groups_users do |t|
      t.belongs_to :group
      t.belongs_to :user
    end
  end
end
