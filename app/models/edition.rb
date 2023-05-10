class Edition < Sequel::Model(:Edition)
  many_to_one :Race, key: :race_id
end
