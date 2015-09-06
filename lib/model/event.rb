require 'ohm'

class Event < Ohm::Model
  include Ohm::Timestamps

  attribute :type
  index :type

end