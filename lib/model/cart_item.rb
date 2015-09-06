require 'ohm'

class CartItem < Ohm::Model
  include Ohm::Timestamps

  attribute :nav_id
  attribute :tradeReason
  attribute :productVtsz
  attribute :productName
  attribute :adrNumber
  attribute :transportLicense
  attribute :weight
  attribute :value
  attribute :factoryItemNumber
  attribute :importerItemNumber
  attribute :expirationDate
  attribute :batchNumber

  def to_hash
    {:id => id}.merge(@attributes)
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
    nav.merge!({:itemExternalId => [id]})
    nid = nav.delete(:nav_id)
    unless nid.nil?
      nav.merge!({:id => nid})
    end
    {:tradeCardItem => [nav]}
  end

  def update_from_nav(item_hash)
    @attributes[:nav_id] = item_hash['id']
    save
  end

end