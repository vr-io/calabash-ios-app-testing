if !Luffa::Environment.ci?
  describe 'Launcher:  #console_attach' do

    describe '#attach' do

      let(:launcher) { Calabash::Cucumber::Launcher.new }
      let(:other_launcher) { Calabash::Cucumber::Launcher.new }

      let(:launch_options) {
        {
          :app => Resources.shared.app_bundle_path(:cal_smoke_app),
          :device_target => 'simulator',
          :no_stop => true,
          :launch_retries => Luffa::Retry.instance.launch_retries
        }
      }

      def calabash_console_with_strategy(strategy)
        attach_cmd = 'console_attach'

        # :host strategy is hard to automate.
        #
        # The touch causes the app to go into an infinite loop trying to touch
        # the text field.  Manual testing works fine.  Thinking this was race
        # condition on the RunLoop::HostCache, I tried sleeping before the
        # console attach and before the touch; same results - indefinite hanging.
        #
        # Opening a console in a Terminal against the app allows the touch after:
        #
        # > console_attach(:host)
        #
        # I also tried a Timeout.timeout(10), but the timeout was never reached;
        # the popen3 is blocking.
        #
        # The best we can do is to check that the HostCache was read correctly.
        #
        # My best guess is that this has something to do with either:
        # 1. NSLog output crippling UIAutomation.
        # 2. The run_loop repl pipe is somehow blocking.

        dot_irbrc = File.expand_path(File.join("scripts", ".irbrc"))
        if !File.exist?(dot_irbrc)
          raise %Q[
Could not find the .irbrc:

#{dot_irbrc}

                ]
        end

        env = {"CALABASH_IRBRC" => dot_irbrc}
        Open3.popen3(env, "bundle", "exec", "calabash-ios", "console") do |stdin, stdout, stderr, _|
          stdin.puts "ENV['IRBRC']"
          stdin.puts
          stdin.puts "launcher = #{attach_cmd}"
          if strategy == :host
            stdin.puts "raise 'Launcher is nil' if launcher.nil?"
            stdin.puts "raise 'Launcher run_loop is nil' if launcher.run_loop.nil?"
            stdin.puts "raise 'Launcher pid is nil' if launcher.run_loop[:pid].nil?"
            stdin.puts "raise 'Launcher index is not 1' if launcher.run_loop[:index] != 1"
          end
          stdin.puts "touch 'textField'"
          stdin.close
          yield stdout.read.strip, stderr.read.strip
        end
      end

      describe 'can connect to launched apps' do
        if Resources.shared.xcode.version_gte_8?
          it "attaches to DeviceAgent" do
            launcher.relaunch(launch_options)
            expect(launcher.run_loop).not_to be == nil

            other_launcher.attach

            expect(other_launcher.run_loop).not_to be nil

            calabash_console_with_strategy(nil) do |stdout, stderr|
              puts "stdout => #{stdout}"
              puts "stderr => #{stderr}"
              expect(stdout[/Error/,0]).to be == nil
              expect(stderr).to be == ''
            end
          end
        else

          before(:each) { FileUtils.rm_rf(RunLoop::HostCache.default_directory) }

          if Luffa::Environment.travis_ci?
            # host and shared_element do not like Travis
            strategies = [:preferences]
          else
            strategies = [:preferences, :host, :shared_element]
          end

          strategies.each do |strategy|
            it strategy do

              launch_options[:uia_strategy] = strategy

              launcher.relaunch(launch_options)
              expect(launcher.run_loop).not_to be == nil

              other_launcher.attach

              expect(other_launcher.run_loop).not_to be nil
              expect(other_launcher.run_loop[:uia_strategy]).to be == strategy

              calabash_console_with_strategy(strategy) do |stdout, stderr|
                puts "stdout => #{stdout}"
                puts "stderr => #{stderr}"
                expect(stdout[/Error/,0]).to be == nil
                expect(stderr).to be == ''
              end
            end
          end
        end
      end
    end
  end
end
