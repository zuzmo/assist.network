require 'ohm'
require 'ohm/datatypes'
require 'ohm-zset'
require_relative 'cart'
require_relative 'location'

class Order < Ohm::Model
  include Ohm::Timestamps

  zset      :carts, :Cart, :orderNumber
  reference :loadLocation, :Location
  reference :unloadLocation, :Location
  attribute :ownerID
  index     :ownerID
  attribute :userID
  index     :userID
  attribute :customerOrderID
  attribute :tradeType
  attribute :modByCarrierEnabled
  attribute :orderByCarrierEnabled
  attribute :closeByCarrierEnabled
  attribute :unloadReporter
  attribute :partnerID
  index     :partnerID
  attribute :carrierID
  index     :carrierID
  attribute :carrierText
  attribute :sellerName
  attribute :sellerVatNumber
  attribute :sellerCountry
  attribute :sellerAddress
  attribute :destinationName
  attribute :destinationVatNumber
  attribute :destinationCountry
  attribute :destinationAddress

  def to_hash
    order_hash = {:id => id.to_i}.merge(@attributes)
    order_hash.merge!({:loadLocation => loadLocation.to_hash}) unless loadLocation.nil?
    order_hash.merge!({:unloadLocation => unloadLocation.to_hash}) unless unloadLocation.nil?
    order_hash.merge!({:carts => carts.to_a.map{|e| e.to_hash}})
  end

  def update_from_hash(order_hash)
    carts_array = order_hash.delete('carts')
    load_hash = order_hash.delete('loadLocation')
    unload_hash = order_hash.delete('unloadLocation')
    update(order_hash)
    loadLocation.update(load_hash)
    unloadLocation.update(unload_hash)
    carts_array.each_with_index do |cart_hash, index|
      cart = carts.get(index)
      if cart.nil?
        cart = Cart.create_from_hash(cart_hash.merge({:order => self}))
        carts.add(cart)
        parent_flow = ElogFlow.find(order_id: id).first
        ElogFlow.create(order: self, cart: cart).state_name = parent_flow.state_name
      else
        cart.update_from_hash(cart_hash.merge({:order => self}))
      end
    end
  end

  def self.create_from_hash(order_hash)
    carts_array = order_hash.delete('carts')
    load_hash = order_hash.delete('loadLocation')
    unload_hash = order_hash.delete('unloadLocation')
    instance = Order.create(order_hash)
    instance.loadLocation = Location.create(load_hash)
    instance.unloadLocation = Location.create(unload_hash)
    carts_array.each do |cart_hash|
      instance.carts.add(Cart.create_from_hash(cart_hash.merge({:order => instance})))
    end
    instance.save
  end

  def self.create_from_csv(csv_hash)
    instance = nil
    cart = nil
    csv_hash.each do |csv_row|
      if instance.nil?

        ['loadDate', 'arrivalDate', 'expirationDate'].each do |date|
          csv_row[date] = Time.xmlschema(csv_row[date]).to_i
        end

        order_hash = csv_row.select { |key, value| Order.attributes.include?(key.to_sym) }
        instance = Order.create(order_hash)

        load_hash = csv_row.select { |key, value| /^load/ =~ key }.map{ |key, value| [key.sub(/^load/, ''), value]}.select { |key, value| Location.attributes.include?(key.to_sym) }
        instance.loadLocation = Location.create(load_hash)

        unload_hash = csv_row.select { |key, value| /^unload/ =~ key }.map{ |key, value| [key.sub(/^unload/, ''), value]}.select { |key, value| Location.attributes.include?(key.to_sym) }
        instance.unloadLocation = Location.create(unload_hash)

        cart_hash = csv_row.select { |key, value| Cart.attributes.include?(key.to_sym) }
        cart = Cart.create(cart_hash.merge({:orderNumber => SecureRandom.uuid, :order => instance}))

        instance.carts.add(cart)
        instance.save
      end

      item_hash = csv_row.select { |key, value| CartItem.attributes.include?(key.to_sym) }
      cart.items.add(CartItem.create(item_hash))
      cart.save
    end
    instance
  end

end