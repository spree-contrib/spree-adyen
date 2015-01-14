class AddAdditionalDataAliasInAdyenNotifications < ActiveRecord::Migration
  def change
    add_column :adyen_notifications, :additional_data_alias_type, :string
    add_column :adyen_notifications, :additional_data_alias,      :string
  end
end
