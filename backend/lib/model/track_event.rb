require 'ohm'
require 'ohm/datatypes'

class TrackEvent < Ohm::Model
  include Ohm::Timestamps

  reference :vehicle, :Vehicle

  attribute :gps_longitude
  attribute :gps_latitude

  def to_hash
    {:id => id.to_i, :vehicle => vehicle.to_hash}.merge(@attributes)
  end

end