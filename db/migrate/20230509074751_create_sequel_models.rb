class CreateSequelModels < ActiveRecord::Migration[5.2]
  def change
    create_table :editions do |t|
      t.string :name
      t.bigint :race_id
    end

    create_table :races do |t|
      t.string :name
      t.bigint :type
    end

    create_table :race_types do |t|
      t.string :name
    end
  end
end
