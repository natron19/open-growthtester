class CreateLaunchContexts < ActiveRecord::Migration[8.1]
  def change
    create_table :launch_contexts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string  :product_name,     null: false
      t.text    :description,      null: false
      t.string  :target_audience,  null: false
      t.string  :growth_challenge, null: false
      t.timestamps null: false
    end

    add_index :launch_contexts, :created_at
  end
end
