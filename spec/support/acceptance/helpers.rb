require 'puppet_litmus'

class Target
  include PuppetLitmus

  attr_reader :uri

  def initialize(uri)
    @uri = uri
  end

  def bolt_config
    inventory_hash = LitmusHelpers.inventory_hash_from_inventory_file
    LitmusHelpers.config_from_node(inventory_hash, @uri)
  end

  # Make sure that ENV['TARGET_HOST'] is set to uri
  # before each PuppetLitmus method call. This makes it
  # so if we have an array of targets, say 'agents', then
  # code like agents.each { |agent| agent.bolt_upload_file(...) }
  # will work as expected. Otherwise if we do this in, say, the
  # constructor, then the code will only work for the agent that
  # most recently set the TARGET_HOST variable.
  PuppetLitmus.instance_methods.each do |name|
    m = PuppetLitmus.instance_method(name)
    define_method(name) do |*args, &block|
      ENV['TARGET_HOST'] = uri
      m.bind(self).call(*args, &block)
    end
  end
end

class TargetNotFoundError < StandardError; end
module TargetHelpers
  def master
    target('master', 'acceptance:provision_vms', 'master')
  end
  module_function :master

  def target(name, setup_task, role)
    @targets ||= {}

    unless @targets[name]
      # Find the target
      inventory_hash = LitmusHelpers.inventory_hash_from_inventory_file
      targets = LitmusHelpers.find_targets(inventory_hash, nil)
      target_uri = targets.find do |target|
        vars = LitmusHelpers.vars_from_node(inventory_hash, target) || {}
        roles = vars['roles'] || []
        roles.include?(role)
      end
      unless target_uri
        raise TargetNotFoundError, "none of the targets in 'inventory.yaml' have the '#{role}' role set. Did you forget to run 'rake #{setup_task}'?"
      end
      @targets[name] = Target.new(target_uri)
    end

    @targets[name]
  end
  module_function :target
end

module LitmusHelpers
  extend PuppetLitmus
end
