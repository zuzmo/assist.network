require 'ohm'

class Location  < Ohm::Model
  include Ohm::Timestamps

  attribute :name
  attribute :VATNumber
  attribute :phone
  attribute :email
  attribute :country
  attribute :zipCode
  attribute :city
  attribute :street
  attribute :streetType
  attribute :streetNumber
  attribute :lotNumber

  def to_hash
    {:id => id.to_i}.merge(@attributes)
  end

  def to_nav
    nav = Hash.new
    @attributes.each do |key, value|
      unless value.nil? or value == ''
        nav.merge!({key => [value]})
      end
    end
    nav.delete(:created_at)
    nav.delete(:updated_at)
    nav
  end

end