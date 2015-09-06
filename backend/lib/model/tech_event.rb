require 'ohm'
require 'ohm/datatypes'

class TechEvent < Ohm::Model
  include Ohm::Timestamps

  attribute :type
  index     :type
  attribute :message

  def to_hash
    {:id => id.to_i}.merge(@attributes)
  end

end