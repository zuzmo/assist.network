require 'ohm'
require 'ohm-zset'
require_relative 'tech_event'

class BusinessEvent < Ohm::Model
  include Ohm::Timestamps

  zset      :tech_events, :TechEvent, :created_at
  attribute :type
  index     :type
  attribute :label

  def to_hash
    tech_array = Array.new
    tech_events.each do |tech|
      tech_array << tech.to_hash
    end
    {:id => id.to_i}.merge(@attributes).merge({:tech_events => tech_array})
  end

end