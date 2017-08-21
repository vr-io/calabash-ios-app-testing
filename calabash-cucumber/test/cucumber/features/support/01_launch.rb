
module Calabash
  class Launchctl
    require "singleton"
    include Singleton

    require "calabash-cucumber/launcher"
    require "calabash-cucumber/environment"

    attr_reader :first_launch
    attr_reader :launcher

    def initialize
      @first_launch = true
      @launcher = Calabash::Cucumber::Launcher.new
    end

    def launch(options)
      launcher.relaunch(options)
      @first_launch = false
    end

    def launcher
      @launcher
    end

    def first_launch
      @first_launch
    end

    def shutdown
      # Might not be necessary?
      launcher.instance_variable_set(:@run_loop, nil)
      launcher.instance_variable_set(:@automator, nil)
      @first_launch = true
    end

    def lp_server_running?
      begin
        running = launcher.ping_app
      rescue Errno::ECONNREFUSED => _
        running = false
      end

      running
    end

    def device_agent_running?
      if !options[:cbx_launcher]
        raise RuntimeError, "Don't call this method if you are running with Instruments"
      end

      if launcher.automator.nil?
        return false
      end

      launcher.automator.client.running?
    end

    def running?
      return false if first_launch
      return false if !launcher.run_loop
      return false if !launcher.automator

      return false if !lp_server_running?

      running = true

      if options[:cbx_launcher]
        device_agent_running?
      end

      running
    end

    def xcode
      Calabash::Cucumber::Environment.xcode
    end

    def instruments
      Calabash::Cucumber::Environment.instruments
    end

    def simctl
      Calabash::Cucumber::Environment.simctl
    end

    def environment
      {
        :simctl => self.simctl,
        :instruments => self.instruments,
        :xcode => self.xcode
      }
    end

    def options
      @options ||= begin
        if xcode.version_gte_8?
          automator = {
            :automator => :device_agent
          }
        else
          automator = {
            :automator => :instruments
          }
        end

        automator.merge(environment)
      end
    end

    def device
      @device ||= RunLoop::Device.detect_device({}, xcode, simctl, instruments)
    end
  end
end

Before("@restart_before") do |_|
  calabash_exit
  Calabash::Launchctl.instance.shutdown
end

Before do |scenario|

  options = {
    # Add launch options here.
    # Maintainers can use:
    #   cbx_launcher => :xcodebuild
    # when debugging the DeviceAgent
  }

  merged_options = options.merge(Calabash::Launchctl.instance.options)

  if !Calabash::Launchctl.instance.running?
    Calabash::Launchctl.instance.launch(merged_options)
  end
end

After("@restart_after") do |_|
  calabash_exit
  Calabash::Launchctl.instance.shutdown
end

After("@stop_after") do |_|
  Calabash::Launchctl.instance.launcher.stop
  Calabash::Launchctl.instance.shutdown
end

After do |scenario|

  case :shutdown
  when :shutdown
    if scenario.failed?
      calabash_exit
    end
  when :exit
    if scenario.failed?
      exit!(1)
    end
  end
end
