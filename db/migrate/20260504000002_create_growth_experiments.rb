class CreateGrowthExperiments < ActiveRecord::Migration[8.1]
  def change
    create_table :growth_experiments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :launch_context, null: false, foreign_key: true, type: :uuid
      t.references :user,           null: false, foreign_key: true, type: :uuid
      t.string  :name,           null: false
      t.text    :hypothesis,     null: false
      t.string  :channel,        null: false
      t.integer :impact,         null: false
      t.integer :confidence,     null: false
      t.integer :effort,         null: false
      t.text    :execution_note
      t.string  :status,         null: false, default: "idea"
      t.text    :gemini_raw
      t.timestamps null: false
    end

    add_index :growth_experiments, :status
  end
end
