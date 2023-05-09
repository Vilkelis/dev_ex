class CreateTestTables < ActiveRecord::Migration[5.2]
  def change
    create_table :dev_ex_datas do |t|
      t.string :description
      t.references :ref1
      t.references :ref2
      t.date :start_date
      t.timestamps
    end

    create_table :dev_ex_refs do |t|
      t.string :name
      t.timestamps
    end
  end
end
