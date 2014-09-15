require 'pry'
require 'leibniz/version'
require 'kitchen'
require 'forwardable'
require 'ipaddr'

module Kitchen
  class Config
    def new_logger(suite, platform, index)
      name = instance_name(suite, platform)
      logger_opts = {
        :color    => Color::COLORS[index % Color::COLORS.size].to_sym,
        :level    => Util.to_logger_level(Leibniz::Config.log_level),
        :progname => name
      }
      if Leibniz::Config.log_to_file
        logger_opts[:logdev] = File.join(log_root, "#{name}.log")
      end
      Logger.new logger_opts
    end
  end
end

module Leibniz

  class Config
    class Driver
      @@custom_attr_keys = [:memory, :cpuexecutioncap]
      attr_accessor *@@custom_attr_keys

      # Returns an array of custom attributes that can be used in configuring
      # the vagrant driver
      def custom_attrs
        Hash[@@custom_attr_keys.map {|k| [k, self.send(k)]}]
        .reject{|k,v| v == nil}
      end

    end

    # Defaults
    @log_to_file = false
    @log_level = :info
    @driver = Driver.new

    class << self
      attr_accessor :log_to_file, :log_level
      attr_reader :driver
    end
  end

  def self.configure
    yield self::Config
  end

  def self.build(specification)
    leibniz_yaml = YAML.load_file(".leibniz.yml")
    loader = KitchenLoader.new(specification, leibniz_yaml)
    config = Kitchen::Config.new(:loader => loader)
    Infrastructure.new(config.instances)
  end

  class Infrastructure

    def initialize(instances)
      @nodes = Hash.new
      instances.each do |instance|
        @nodes[instance.name.sub(/^leibniz-/, '')] = Node.new(instance)
      end
    end

    def [](name)
      @nodes[name]
    end

    def converge
      @nodes.each_pair { |name, node| node.converge }
    end

    def destroy
      @nodes.each_pair { |name, node| node.destroy }
    end

  end

  class Node

    extend Forwardable

    def_delegators :@instance, :create, :converge, :setup, :verify, :destroy, :test

    def initialize(instance)
      @instance = instance
    end

    def ip
      instance.driver[:ipaddress]
    end

    private

    attr_reader :instance
  end

  class KitchenLoader

    def initialize(specification, config)
      @config = config
      @last_octet = @config['last_octet']
      @platforms = specification.hashes.map do |spec|
        create_platform(spec)
      end
      @suites = specification.hashes.map do |spec|
        create_suite(spec)
      end
    end

    def read
      {
        :driver_plugin => @config['driver'],
        :platforms => platforms,
        :suites => suites
      }
    end

    private

    attr_reader :platforms, :suites

    def create_suite(spec)
      suite = Hash.new
      attr_keys = [:name, :run_list, :data_bags_path, :attributes]
      attr_keys.each do |attr_key|
        suite[attr_key] = @config['suites'].first[attr_key.to_s]
      end
      suite
    end

    def create_platform(spec)
      distro = "#{spec['Operating System']}-#{spec['Version']}"
      ipaddress = IPAddr.new(@config['network']).succ.succ.to_s
      platform = Hash.new
      platform[:name] = spec["Server Name"]
      platform[:driver_config] = Hash.new
      platform[:driver_config][:box] = "opscode-#{distro}"
      platform[:driver_config][:box_url] = "https://opscode-vm-bento.s3.amazonaws.com/vagrant/virtualbox/opscode_#{distro}_chef-provisionerless.box"
      platform[:driver_config][:network] = [["private_network", {:ip => ipaddress}]]
      platform[:driver_config][:require_chef_omnibus] = spec["Chef Version"] || true
      platform[:driver_config][:ipaddress] = ipaddress
      platform[:driver_config][:customize] = Leibniz::Config.driver.custom_attrs
      platform[:run_list] = spec["Run List"].split(",")
      platform
    end
  end
end

