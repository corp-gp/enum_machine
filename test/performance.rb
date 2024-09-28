# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails", "~> 7.0"
  gem "sqlite3"
  gem "state_machines", github: "state-machines/state_machines"
  gem "state_machines-activerecord", github: "state-machines/state_machines-activerecord"
  gem "aasm", github: "aasm/aasm"
  gem "enum_machine", github: "corp-gp/enum_machine"
  gem "benchmark-ips"
end

require "active_record"
require "benchmark/ips"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
# ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :orders, force: true do |t|
    t.string :name
    t.string :state
  end
end

STATES_IN_TRANSIT = %w[shipped delivered_to_office delivered_to_courier_city].freeze

class OrderEnumMachine < ActiveRecord::Base

  self.table_name = :orders

  enum_machine :state, %w[
    forming confirmed ready_for_collecting collecting collected packed wait_shipment back_picking cancelled shipped
    delivered_to_office delivered_to_courier_city part_obtain obtain overdue rejection closed returned merged searched lost
  ] do
    transitions(
      [nil] | %w[confirmed ready_for_collecting]                                                  => "forming",
      [nil] | %w[forming confirmed]                                                               => "ready_for_collecting",
      [nil] | %w[forming ready_for_collecting]                                                    => "confirmed",
      "ready_for_collecting"                                                                      => "collecting",
      "collecting"                                                                                => "collected",
      %w[collecting collected]                                                                    => "packed",
      "packed"                                                                                    => "wait_shipment",
      %w[forming confirmed ready_for_collecting collecting packed wait_shipment cancelled]        => "back_picking",
      %w[forming confirmed ready_for_collecting collecting collected packed wait_shipment]        => "cancelled",
      "wait_shipment"                                                                             => "shipped",
      %w[wait_shipment shipped]                                                                   => %w[delivered_to_office delivered_to_courier_city],
      %w[wait_shipment overdue rejection returned searched lost obtain] | STATES_IN_TRANSIT       => "part_obtain",
      %w[wait_shipment overdue rejection returned searched lost part_obtain] | STATES_IN_TRANSIT  => "obtain",
      %w[wait_shipment obtain searched] | STATES_IN_TRANSIT                                       => "overdue",
      %w[wait_shipment obtain part_obtain overdue searched] | STATES_IN_TRANSIT                   => "rejection",
      %w[overdue rejection searched lost]                                                         => "returned",
      %w[part_obtain obtain searched lost]                                                        => "closed",
      %w[forming confirmed ready_for_collecting packed wait_shipment]                             => "merged",
      %w[wait_shipment shipped part_obtain obtain overdue rejection lost] | STATES_IN_TRANSIT     => "searched",
      %w[wait_shipment shipped part_obtain obtain overdue rejection searched] | STATES_IN_TRANSIT => "lost",
    )
  end

end

class OrderAasm < ActiveRecord::Base

  include AASM

  self.table_name = :orders

  aasm :state do # rubocop:disable Metrics/BlockLength
    state :default, initial: true
    state :forming
    state :confirmed
    state :ready_for_collecting
    state :collecting
    state :collected
    state :packed
    state :wait_shipment
    state :back_picking
    state :cancelled
    state :shipped
    state :delivered_to_office
    state :delivered_to_courier_city
    state :part_obtain
    state :obtain
    state :overdue
    state :rejection
    state :closed
    state :returned
    state :merged
    state :searched
    state :lost

    event :to_forming do
      transitions from: %i[default confirmed ready_for_collecting], to: :forming
    end

    event :to_ready_for_collecting do
      transitions from: %i[default forming confirmed], to: :ready_for_collecting
    end

    event :to_confirmed do
      transitions from: %i[default forming ready_for_collecting], to: :confirmed
    end

    event :to_collecting do
      transitions from: :ready_for_collecting, to: :collecting
    end

    event :to_collected do
      transitions from: :collecting, to: :collected
    end

    event :to_packed do
      transitions from: %i[collecting collected], to: :packed
    end

    event :to_wait_shipment do
      transitions from: :packed, to: :wait_shipment
    end

    event :to_back_picking do
      transitions from: %i[forming confirmed ready_for_collecting collecting packed wait_shipment cancelled], to: :back_picking
    end

    event :to_cancelled do
      transitions from: %i[forming confirmed ready_for_collecting collecting collected packed wait_shipment], to: :cancelled
    end

    event :to_shipped do
      transitions from: :wait_shipment, to: :shipped
    end

    event :to_delivered do
      transitions from: %i[wait_shipment shipped], to: %i[delivered_to_office delivered_to_courier_city]
    end

    event :to_part_obtain do
      transitions from: %i[wait_shipment overdue rejection returned searched lost obtain] | STATES_IN_TRANSIT, to: :part_obtain
    end

    event :to_obtain do
      transitions from: %i[wait_shipment overdue rejection returned searched lost part_obtain] | STATES_IN_TRANSIT, to: :obtain
    end

    event :to_overdue do
      transitions from: %i[wait_shipment obtain searched] | STATES_IN_TRANSIT, to: :overdue
    end

    event :to_rejection do
      transitions from: %i[wait_shipment obtain part_obtain overdue searched] | STATES_IN_TRANSIT, to: :rejection
    end

    event :to_returned do
      transitions from: %i[overdue rejection searched lost], to: :returned
    end

    event :to_closed do
      transitions from: %i[part_obtain obtain searched lost], to: :closed
    end

    event :to_merged do
      transitions from: %i[forming confirmed ready_for_collecting packed wait_shipment], to: :merged
    end

    event :to_searched do
      transitions from: %i[wait_shipment shipped part_obtain obtain overdue rejection lost] | STATES_IN_TRANSIT, to: :searched
    end

    event :to_lost do
      transitions from: %i[wait_shipment shipped part_obtain obtain overdue rejection searched] | STATES_IN_TRANSIT, to: :lost
    end
  end

end

class OrderStateMachines < ActiveRecord::Base

  self.table_name = :orders

  state_machine :state, initial: nil do
    event :to_forming do
      transition [nil, "confirmed", "ready_for_collecting"] => "forming"
    end

    event :to_ready_for_collecting do
      transition [nil, "forming", "confirmed"] => "ready_for_collecting"
    end

    event :to_confirmed do
      transition [nil, "forming", "ready_for_collecting"] => "confirmed"
    end

    event :to_collecting do
      transition "ready_for_collecting" => "collecting"
    end

    event :to_collected do
      transition "collecting" => "collected"
    end

    event :to_packed do
      transition %w[collecting collected] => "packed"
    end

    event :to_wait_shipment do
      transition "packed" => "wait_shipment"
    end

    event :to_back_picking do
      transition %w[forming confirmed ready_for_collecting collecting packed wait_shipment cancelled] => "back_picking"
    end

    event :to_cancelled do
      transition %w[forming confirmed ready_for_collecting collecting collected packed wait_shipment] => "cancelled"
    end

    event :to_shipped do
      transition "wait_shipment" => "shipped"
    end
    event :to_delivered do
      transition %w[wait_shipment shipped] => %w[delivered_to_office delivered_to_courier_city]
    end

    event :to_part_obtain do
      transition %w[wait_shipment overdue rejection returned searched lost obtain] | STATES_IN_TRANSIT => "part_obtain"
    end

    event :to_obtain do
      transition %w[wait_shipment overdue rejection returned searched lost part_obtain] | STATES_IN_TRANSIT => "obtain"
    end

    event :to_overdue do
      transition %w[wait_shipment obtain searched] | STATES_IN_TRANSIT => "overdue"
    end

    event :to_rejection do
      transition %w[wait_shipment obtain part_obtain overdue searched] | STATES_IN_TRANSIT => "rejection"
    end

    event :to_returned do
      transition %w[overdue rejection searched lost] => "returned"
    end

    event :to_closed do
      transition %w[part_obtain obtain searched lost] => "closed"
    end

    event :to_merged do
      transition %w[forming confirmed ready_for_collecting packed wait_shipment] => "merged"
    end

    event :to_searched do
      transition %w[wait_shipment shipped part_obtain obtain overdue rejection lost] | STATES_IN_TRANSIT => "searched"
    end

    event :to_lost do
      transition %w[wait_shipment shipped part_obtain obtain overdue rejection searched] | STATES_IN_TRANSIT => "lost"
    end
  end

end

def pp_title(name, stmt)
  "#{name.rjust(15, ' ')} |#{stmt.rjust(50)}"
end

order_attrs = { state: "confirmed", name: "Petrov" }

order_enum_machine   = OrderEnumMachine.create!(order_attrs)
order_state_machines = OrderStateMachines.create!(order_attrs)
order_aasm           = OrderAasm.create!(order_attrs)

Benchmark.ips(quiet: true) do |x|
  x.report(pp_title("enum_machine", "order.state.can_closed?")) do
    order_enum_machine.state.can_closed?
  end

  x.report(pp_title("state_machines", "order.can_to_closed?")) do
    order_state_machines.can_to_closed?
  end

  x.report(pp_title("aasm", "order.may_to_closed?")) do
    order_aasm.may_to_closed?
  end

  x.compare!
end

Benchmark.ips(quiet: true) do |x|
  x.report(pp_title("enum_machine", "order.state.forming?")) do
    order_enum_machine.state.forming?
  end

  x.report(pp_title("state_machines", "order.forming?")) do
    order_state_machines.forming?
  end

  x.report(pp_title("aasm", "order.forming?")) do
    order_aasm.forming?
  end

  x.compare!
end

Benchmark.ips(quiet: true) do |x|
  x.report(pp_title("enum_machine", "Order::STATE.values")) do
    OrderEnumMachine::STATE.values
  end

  x.report(pp_title("state_machines", "Order.state_machines[:state].states.map(&:value)")) do
    OrderStateMachines.state_machines[:state].states.map(&:value)
  end

  x.report(pp_title("aasm", "Order.aasm(:state).states.map(&:name)")) do
    OrderAasm.aasm(:state).states.map(&:name)
  end

  x.compare!
end

Benchmark.ips(quiet: true) do |x|
  x.report(pp_title("enum_machine", 'order.state = "forming" and order.valid?')) do
    order = order_enum_machine.dup
    order.state = "forming" and order.valid?
  end

  x.report(pp_title("state_machines", 'order.state_event = "to_forming" and order.valid?')) do
    order = order_state_machines.dup
    order.state_event = "to_forming" and order.valid?
  end

  x.report(pp_title("aasm", "order.to_forming")) do
    order = order_aasm.dup
    order.to_forming
  end

  x.compare!
end
