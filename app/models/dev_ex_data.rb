class DevExData < ApplicationRecord
  self.table_name = 'dev_ex_datas'
  belongs_to :ref1, class_name: 'DevExRef'
  belongs_to :ref2, class_name: 'DevExRef'
end
