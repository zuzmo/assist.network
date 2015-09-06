require 'ohm'
require 'ohm-zset'
require_relative 'cart_item'
require_relative 'vehicle'

class Cart < Ohm::Model
  include Ohm::Timestamps

  zset :items, :CartItem, :productName

  reference :order, :Order
  reference :vehicle, :Vehicle
  reference :vehicle2, :Vehicle
  reference :vehicle3, :Vehicle

  attribute :tcn
  index     :tcn
  attribute :orderNumber
  index     :orderNumber
  attribute :loadDate
  attribute :arrivalDate

  def merge(cart)
    cart.items.each do |i|
        self.items << i
    end
  end

  def split_items(items)
    newcart = Cart.create(orderNumber: SecureRandom.uuid)
    items.each do |i|
      items.delete(i)
      newcart.items.add(i)
    end
    newcart
  end

  def to_hash
    flow = ElogFlow.find(cart_id: id).first
    cart_hash = {:id => id.to_i, :state => flow.state_name, :message => flow.last_error}.merge(@attributes)
    cart_hash.merge!({:vehicle => vehicle.to_hash}) unless vehicle.nil?
    cart_hash.merge!({:vehicle2 => vehicle2.to_hash}) unless vehicle2.nil?
    cart_hash.merge!({:vehicle3 => vehicle3.to_hash}) unless vehicle3.nil?
    cart_hash.merge!({:items => items.to_a.map{|e| e.to_hash}})
  end

  def to_nav
    nav = Hash.new
    @attributes.each do |key, value|
      unless value.nil? or value == ''
        nav.merge!({key => [value]})
      end
    end
    order.attributes.each do |key, value|
      unless value.nil? or value == ''
        nav.merge!({key => [value]})
      end
    end
    nav.delete(:created_at)
    nav.delete(:updated_at)
    nav.delete(:order_id)
    nav.delete(:orderByCarrierEnabled)
    nav.delete(:closeByCarrierEnabled)
    nav.delete(:ownerID)
    nav.delete(:userID)
    nav.delete(:partnerID)
    nav.delete(:carrierID)
    nav.merge!({:loadDate => [Time.at(nav.delete(:loadDate)[0].to_i).strftime('%Y-%m-%dT%H:%M:%S%:z')]})
    nav.merge!({:arrivalDate => [Time.at(nav.delete(:arrivalDate)[0].to_i).strftime('%Y-%m-%dT%H:%M:%S%:z')]})
    unless nav.delete(:loadLocation_id).nil?
      nav.merge!({:loadLocation => [order.loadLocation.to_nav]})
    end
    unless nav.delete(:unloadLocation_id).nil?
      nav.merge!({:unloadLocation => [order.unloadLocation.to_nav]})
    end
    unless nav.delete(:vehicle_id).nil?
      nav.merge!({:vehicle => [vehicle.to_nav]})
    end
    unless nav.delete(:vehicle2_id).nil?
      nav.merge!({:vehicle2 => [vehicle2.to_nav]})
    end
    unless nav.delete(:vehicle3_id).nil?
      nav.merge!({:vehicle3 => [vehicle3.to_nav]})
    end
    items_array = Array.new
    items.each do |item|
      items_array << item.to_nav
    end
    nav.merge!({:items => items_array})

    # Signature generation
    nav.merge!({:signature => Digest::SHA512.hexdigest(nav.flatten().join('') + CONFIG['secret']).upcase})

    #
    if tcn.nil?
      operation = 'create'
    else
      operation = 'modify'
    end
    {:tradeCardOperations => [{
                                  :tradeCardOperation => [{
                                                           :index => ['1'],
                                                           :operation => [operation],
                                                           :tradeCard => [nav]
                                                       }]
                              }]
    }
  end

  def update_from_nav(cart_hash)
    @attributes[:tcn] = cart_hash['tradeCardOperationsResults'][0]['operationResult'][0]['tradeCardInfo'][0]['tcn'][0]
    save
    cart_hash['tradeCardOperationsResults'][0]['operationResult'][0]['tradeCardInfo'][0]['items'][0]['tradeCardItem'].each do |item_hash|
      CartItem[item_hash['itemExternalId'][0]].update_from_nav(item_hash)
    end
  end

  def update_from_hash(cart_hash)
    items_array = cart_hash.delete('items')
    update(cart_hash)
    unless items_array.nil?
      items_array.each_with_index do |item_hash, index|
        item = items.get(index)
        if item.nil?
          items.add(CartItem.create(item_hash))
        else
          item.update(item_hash)
        end
      end
    end
  end

  def self.create_from_hash(cart_hash)
    items_array = cart_hash.delete('items')
    instance = Cart.create(cart_hash.merge({:orderNumber => SecureRandom.uuid}))
    items_array.each do |item_hash|
      instance.items.add(CartItem.create(item_hash))
    end
    instance.save
  end

end