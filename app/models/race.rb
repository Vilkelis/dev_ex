class Race < Sequel::Model(:Race)
  many_to_one :rtype, class: :RaceType, key: :type
  one_to_many :Edition, class: :Edition, key: :race_id
end
