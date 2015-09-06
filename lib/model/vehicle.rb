require 'ohm'
require 'ohm/contrib'

class Vehicle < Ohm::Model
  include Ohm::Timestamps

  attribute :companyID
  index     :companyID
  attribute :plateNumber
  index     :plateNumber
  unique    :plateNumber
  attribute :country
  attribute :vehicleType
  attribute :active
  index     :active

  def to_hash
    {:id => id.to_i}.merge(@attributes)
  end

  def to_nav
    nav = Hash.new
    @attributes.each do |key, value|
      nav.merge!({key => [value]})
    end
    nav.delete(:created_at)
    nav.delete(:updated_at)
    nav.delete(:companyID)
    nav.delete(:vehicleType)
    nav.delete(:active)
    nav
  end

end