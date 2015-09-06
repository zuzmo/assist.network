require 'grape'
require 'json'
require 'csv'
require_relative 'elog_helpers'
require_relative '../lib/model/vehicle'
require_relative '../lib/model/order'
require_relative '../lib/model/elogflow'
require_relative '../lib/model/business_event'

LIMIT = 20

module Elog
  class API < Grape::API

    #version 'v1', using: :header, vendor: 'elog'
    format :json

    helpers ElogHelpers

=begin
    resource :test do

      params do
        requires :id, type: Integer, desc: 'Event id'
      end
      route_param :id do
        get do
          authenticate!
          #flow = ElogFlow.find(cart_id: params[:id]).first
          #flow.current_state = :delivery
          #flow.delivered(nil, BusinessEvent.create(type: 'delivery'))
          Cart.attributes
        end
      end

    end
=end

    # Vehicle handling
    resource :vehicle do

      desc 'Return list of vehicles'
      params do
        requires :companyID, type: Integer, desc: 'Company id'
        optional :page, type: Integer, desc: 'Page num'
        optional :limit, type: Integer, desc: 'Page size'
      end
      get :list do
        authenticate!
        set = Vehicle.find(companyID: params['companyID'])
        paginate(set, params[:id], params[:limit])
      end

      desc 'Return a vehicle'
      params do
        requires :vehicleID, type: Integer, desc: 'Vehicle id'
      end
      route_param :vehicleID do
        get do
          authenticate!
          vehicle = Vehicle[params[:vehicleID]]
          if vehicle.nil?
            {:error => 'Vechicle not found'}
          else
            vehicle.to_hash
          end
        end
      end

      desc 'Create/Update a vehicle'
      params do
        requires :vehicle, type: Hash, desc: 'Order'
      end
      post do
        authenticate!
        rescue_db_errors {
          vehicles = Vehicle.find(plateNumber: params[:vehicle][:plateNumber])
          if vehicles.count == 0
            vehicle = Vehicle.create(params[:vehicle])
          else
            vehicle = vehicles.first
            vehicle.update(params[:vehicle])
          end
          {:vehicleID => vehicle.id.to_i, :success => true}
        }
      end

    end

    # Order listing
    resource :order do

      desc 'Return list of orders'
      params do
        optional :ownerID, type: Integer, desc: 'Owner id'
        optional :userID, type: Integer, desc: 'User id'
        optional :partnerID, type: Integer, desc: 'Partner id'
        optional :carrierID, type: Integer, desc: 'Carrier id'
        optional :page, type: Integer, desc: 'Page num'
        optional :limit, type: Integer, desc: 'Page size'
      end
      get :list do
        authenticate!
        find_params = Hash.new
        unless params['ownerID'].nil?
          find_params.merge!({:ownerID => params['ownerID']})
        end
        unless params['userID'].nil?
          find_params.merge!({:userID => params['userID']})
        end
        unless params['partnerID'].nil?
          find_params.merge!({:partnerID => params['partnerID']})
        end
        unless params['carrierID'].nil?
          find_params.merge!({:carrierID => params['carrierID']})
        end
        if find_params.empty?
          set = rescue_db_errors { Order.all }
        else
          set = rescue_db_errors { Order.find(find_params) }
        end
        paginate(set, params[:page], params[:limit])
      end

      desc 'Return an order'
      params do
        requires :id, type: Integer, desc: 'Event id'
      end
      route_param :id do
        get do
          authenticate!
          order = Order[params[:id]]
          if order.nil?
            {:error => 'Order not found'}
          else
            order.to_hash
          end
        end
      end

    end

    # Event handling
    resource :event do

      desc 'Return the list of events of a cart'
      params do
        requires :cartID, type: String, desc: 'Cart id'
        optional :page, type: Integer, desc: 'Page num'
        optional :limit, type: Integer, desc: 'Page size'
      end
      get :list do
        authenticate!
        flow = ElogFlow.find(cart_id: params['cartID']).first
        unless flow.nil?
          {:state => flow.state_name, :events => paginate(flow.business_events, 1, 100), :track_events => paginate(flow.track_events , params[:page], params[:limit])}
        else
          {:error => 'Flow not found'}
        end
      end

      desc 'Return an event'
      params do
        requires :id, type: Integer, desc: 'Event id'
      end
      route_param :id do
        get do
          authenticate!
          BusinessEvent[params[:id]].to_hash
        end
      end

      desc 'Create an event'
      params do
        requires :event, type: String, desc: 'Event type'
        optional :label, type: String, desc: 'Event label'
        optional :cartID, type: Integer, desc: 'Cart id'
        optional :order, type: Hash, desc: 'Order'
        optional :orderCSV, type: String, desc: 'Order in CSV format'
        optional :ownerID, type: Integer, desc: 'Owner id'
        optional :userID, type: Integer, desc: 'User id'
        optional :trackEvent, type: Hash, desc: 'Track event'
      end
      post do
        authenticate!

        # Flow selection
        if params[:event] == 'order_received'
          # Create flow and order
          if params[:orderCSV].nil?
            if params[:order].nil?
              return {:error => 'Order data not found in request'}
            end
            if params[:order][:carts].count > 1
              return {:error => 'Only one cart permitted'}
            end
            # Create order from JSON
            order = Order.create_from_hash(params[:order])
          else
            # Create order from CSV
            csv_hash = CSV.new(params[:orderCSV], :headers => true, :col_sep => ';').to_a.map {|row| row.to_hash }
            if csv_hash.size == 0
              return {:error => 'No rows in CSV'}
            end
            csv_hash[0]['ownerID'] = params[:ownerID] unless params[:ownerID].nil?
            csv_hash[0]['userID'] = params[:userID] unless params[:userID].nil?
            if csv_hash[0]['ownerID'].nil?
              return {:error => 'ownerID is missing'}
            end
            order = Order.create_from_csv(csv_hash)
          end
          flow = ElogFlow.create(order: order, cart: order.carts.get(0))
        else
          # Select existing flow
          flows = ElogFlow.find(cart_id: [params[:cartID]])
          if flows.count == 0
            return {:error => 'Cart not found'}
          end
          flow = flows.first
        end

        # Generate response
        if params[:event] == 'track_event'
          # Add track event
          return {:success => flow.track_event(params[:trackEvent])}
        end

        business_event = BusinessEvent.create(type: params[:event], label: params[:label])
        if params[:event] == 'order_received'
          # Generate create tech event
          business_event.tech_events.add(TechEvent.create(type: 'order_created'))
          flow.business_events.add(business_event)
          {:orderID => flow.order_id.to_i, :success => true}
        else
          # Post event to flow
          sucess = flow.send(params[:event], params[:order], business_event)
          if sucess
            flow.business_events.add(business_event)
            flow.save
          else
            # Remove unsuccessful event
            business_event.delete
          end
          if flow.last_error.nil?
            {:success => sucess}
          else
            {:success => sucess, :error => flow.last_error}
          end
        end
      end

    end

  end

end