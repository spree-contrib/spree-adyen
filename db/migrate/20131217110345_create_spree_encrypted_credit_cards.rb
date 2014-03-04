# @private
class CreateSpreeEncryptedCreditCards < ActiveRecord::Migration
  def self.up
    create_table :spree_encrypted_credit_cards do |t|
      t.integer :month
      t.integer :year
      t.string :name
      t.timestamps
    end
  end

  def self.down
    drop_table :spree_encrypted_credit_cards
  end
end
