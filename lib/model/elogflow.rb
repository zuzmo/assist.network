require 'logger'
require 'ohm'
require 'ohm-zset'
require 'ohm/stateful_model'
require_relative '../../ekaer/ekaer'
require_relative 'order'
require_relative 'business_event'
require_relative 'track_event'

class ElogStates < Ohm::State

  state_machine :state, :initial => :order_processing do

    event :order_approved do
      transition :order_processing => :deposit_calculation
    end

    event :deposit_calculated do
      transition :deposit_calculation => :freight_order_receive
    end

    event :freight_order_received do
      transition :freight_order_receive => :freight_order_process
    end

    event :freight_order_processed do
      transition :freight_order_process => :freight_order_dispatch
    end

    event :freight_order_dispatched do
      transition :freight_order_dispatch => :carrier_confirmation
    end

    event :carrier_confirmed do
      transition :carrier_confirmation => :loading
    end

    event :loaded do
      transition :loading => :load_documentation
    end

    event :load_documented do
      transition :load_documentation => :ekaer_request
    end

    event :ekaer_received do
      transition :ekaer_request => :freight_documents_process
    end

    event :freight_documents_created do
      transition :freight_documents_process => :start_transport
    end

    event :delivery_started do
      transition :start_transport => :track_transport
    end

    event :transport_event do
      transition :track_transport => same
    end

    event :track_event do
      transition :track_transport => same
    end

    event :transport_arrived do
      transition :track_transport => :unload
    end

    event :unloaded do
      transition :unload => :delivery
    end

    event :delivered do
      transition :delivery => :ekaer_closing
    end

    event :ekaer_closed do
      transition :ekaer_closing => :closed
    end

  end
end

class ElogFlow < Ohm::StatefulModel

  use_state_machine ElogStates, :attribute_name => :current_state
  zset      :business_events, :BusinessEvent, :created_at
  zset      :track_events, :TrackEvent, :created_at
  reference :order, :Order
  reference :cart, :Cart
  attribute :last_error

  def order_approved(order_hash, business_event)
    update_order(:order_approved, order_hash, business_event)
  end

  def freight_order_dispatched(order_hash, business_event)
    update_order(:freight_order_dispatched, order_hash, business_event)
  end

  def loaded(order_hash, business_event)
    update_order(:loaded, order_hash, business_event)
  end

  def transport_event(order_hash, business_event)
    success = update_order(:transport_event, order_hash, business_event)
    if success
      begin
        Ekaer.new.modify(cart.to_nav)
        @attributes[:last_error] = nil
        save
        business_event.tech_events.add(TechEvent.create(type: 'ekaer_modified'))
        business_events.add(BusinessEvent.create(type: 'ekaer_modified'))
        fire_state_event(:ekaer_received)
      rescue StandardError => error
        handle_error(error, business_event)
      end
    end
    success
  end

  def load_documented(order_hash, business_event)
    if !can_load_documented?
      return false
    end
    begin
      cart_hash = Ekaer.new.create(cart.to_nav)
      cart.update_from_nav(cart_hash)
      @attributes[:last_error] = nil
      save
      fire_state_event(:load_documented)
      business_event.tech_events.add(TechEvent.create(type: 'ekaer_created'))
      business_events.add(BusinessEvent.create(type: 'ekaer_received'))
      fire_state_event(:ekaer_received)
    rescue StandardError => error
      handle_error(error, business_event)
    end
  end

  def delivered(order_hash, business_event)
    if !can_delivered?
      return false
    end
    begin
      Ekaer.new.close(cart.to_nav)
      @attributes[:last_error] = nil
      save
      fire_state_event(:delivered)
      business_event.tech_events.add(TechEvent.create(type: 'ekaer_closed'))
      business_events.add(BusinessEvent.create(type: 'ekaer_closed'))
      fire_state_event(:ekaer_closed)
    rescue StandardError => error
      handle_error(error, business_event)
    end
  end

  def track_event(event_hash)
    unless can_track_event?
      return false
    end
    track_events.add(TrackEvent.create(event_hash))
    fire_state_event(:track_event)
  end

  private

  def handle_error(error, business_event)
    error_event = BusinessEvent.create(type: business_event.attributes)
    error_event.tech_events.add(TechEvent.create(type: 'server_error', message: error.message))
    business_events.add(error_event)
    @attributes[:last_error] = error.message
    save
    Logger.new(STDERR).error(error.message + "\n" + error.backtrace.join("\n"))
    false
  end

  def update_order(event, order_hash, business_event)
    Logger.new(STDERR).debug(event.to_s + ': '+ cart_id)
    success = fire_state_event(event)
    if success && !order_hash.nil?
      order.update_from_hash(order_hash)
      business_event.tech_events.add(TechEvent.create(type: 'order_modified'))
    end
    success
  end

end