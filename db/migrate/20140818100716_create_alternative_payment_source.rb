class CreateAlternativePaymentSource < ActiveRecord::Migration
  def change
    create_table :spree_alternative_payment_sources do |t|
      t.string :brand_code
      t.integer :payment_method_id
      t.integer :user_id
      t.timestamps
    end
  end
end
