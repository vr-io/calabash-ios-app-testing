describe Calabash::Cucumber::Core do

  before do
    allow(RunLoop::Environment).to receive(:debug?).and_return(true)
  end

  let(:automator) do
    Class.new(Calabash::Cucumber::Automator::Automator) do
      def initialize; ; end
      def swipe(_); :success; end
      def to_s; "#<Automator RSPEC STUB>"; end
      def inspect; to_s; end
      def name; :automator; end
    end.new
  end

  let(:launcher) do
    Class.new do
      def automator; ; end
      def run_loop; ; end
      def instruments?; ; end
      def to_s; "#<Launcher RSPEC STUB>"; end
      def inspect; to_s; end
    end.new
  end

  let(:world) do
    Class.new do
      include Calabash::Cucumber::Core
      include Calabash::Cucumber::WaitHelpers
      def to_s; "#<World RSPEC STUB>"; end
      def inspect; to_s; end

      # The dread Cucumber embed
      def embed(_, _, _); ; end
    end.new
  end

  describe "logging" do
    it "#calabash_warn" do
      actual = capture_stdout do
        world.calabash_warn("You have been warned")
      end.string.gsub(/\e\[(\d+)m/, "")

      expect(actual).to be == "WARN: You have been warned\n"
    end

    it "#calabash_info" do
      actual = capture_stdout do
        world.calabash_info("You have been info'd")
      end.string.gsub(/\e\[(\d+)m/, "").strip

      # The .strip above future proofs against changes to the silly leading
      # space in RunLoop.log_info2.
      expect(actual).to be == "INFO: You have been info'd"
    end

    it "#deprecated" do
      version = '0.9.169'
      dep_msg = 'this is a deprecation message'
      out = capture_stdout do
        world.deprecated(version, dep_msg, :warn)
      end.string.gsub(/\e\[(\d+)m/, "")

      tokens = out.split($-0)
      message = tokens[0]
      expect(message).to be == "WARN: deprecated '#{version}' - #{dep_msg}"
      expect(tokens.count).to be > 5
      expect(tokens.count).to be < 9
    end
  end

  context "#touch" do
    it "calls the automator :touch method" do
      expect(world).to(
        receive(:query_action_with_options).with(:touch, "query", {})
      ).and_return([:view])

      expect(world.touch("query", {})).to be == [:view]
    end

    context "uiquery is nil" do
      it "raises an ArgumentError if there is not an :offset" do
        expect do
          world.touch(nil, {})
        end.to raise_error ArgumentError,
                           /If query is nil, there must be a valid offset/
      end

      it "raises an ArgumentError if there is not a valid :offset" do
        expect do
          world.touch(nil, {offset: { x: 10 }})
        end.to raise_error ArgumentError,
                           /If query is nil, there must be a valid offset/

        expect do
          world.touch(nil, {offset: { y: 10 }})
        end.to raise_error ArgumentError,
                           /If query is nil, there must be a valid offset/
      end
    end
  end

  describe '#scroll' do
    describe 'handling direction argument' do
      describe 'raises error if invalid' do
        it 'keywords' do
          expect do
            world.scroll("query", :sideways)
          end.to raise_error ArgumentError
        end

        it 'strings' do
          expect do
            world.scroll("query", 'diagonal')
          end.to raise_error ArgumentError
        end
      end

      describe 'valid' do
        before do
          expect(Calabash::Cucumber::Map).to receive(:map).twice.and_return [true]
          expect(Calabash::Cucumber::Map).to receive(:assert_map_results).twice.and_return true
        end

        it 'up' do
          expect(world.scroll('', 'up')).to be_truthy
          expect(world.scroll('', :up)).to be_truthy
        end

        it 'down' do
          expect(world.scroll('', 'down')).to be_truthy
          expect(world.scroll('', :down)).to be_truthy
        end

        it 'left' do
          expect(world.scroll('', 'left')).to be_truthy
          expect(world.scroll('', :left)).to be_truthy
        end

        it 'right' do
          expect(world.scroll('', 'right')).to be_truthy
          expect(world.scroll('', :right)).to be_truthy
        end
      end
    end
  end

  context "#swipe" do
    context "it validates its arguments" do
      it "raises an error if direction is invalid" do
        expect do
          world.swipe(:sideways)
        end.to raise_error ArgumentError, /Invalid direction argument/
      end

      it "raises an error if :force option is invalid" do
        expect do
          world.swipe(:left, {:force => :majeure})
        end.to raise_error ArgumentError, /Invalid force option/
      end
    end

    context "valid arguments" do
      before do
        expect(world).to receive(:launcher).and_return launcher
        expect(launcher).to receive(:automator).and_return(automator)
      end

      it "merges the options" do
        merged = {:force => :strong, :query => "query", :direction => :left}
        expect(automator).to(
          receive(:swipe).with(merged).and_return([:view])
        )

        actual = world.swipe(:left, {:force => :strong, :query => "query"})
        expect(actual).to be == [:view]
      end

      it "has defaults for :query and :force" do
        merged = {:force => :normal, :query => nil, :direction => :left}
        expect(automator).to(
          receive(:swipe).with(merged).and_return([:view])
        )

        actual = world.swipe(:left)
        expect(actual).to be == [:view]
      end
    end
  end

  context "#pan" do
    context "raises an ArgumentError if called with an invalid duration" do
      let(:options) { {} }

      it "raises if duration < 0.5 with UIAutomation" do
        expect(world).to receive(:uia_available?).and_return(true)
        options[:duration] = 0.4

        expect do
          world.pan("from", "to", options)
        end.to raise_error ArgumentError, /Invalid duration/
      end

      it "raises if duration <= 0.0 with DeviceAgent" do
        expect(world).to receive(:uia_available?).and_return(false)
        options[:duration] = 0.0

        expect do
          world.pan("from", "to", options)
        end.to raise_error ArgumentError, /Invalid duration/
      end
    end

    it "calls the automator #pan method" do
      expect(world).to receive(:launcher).and_return(launcher)
      expect(launcher).to receive(:automator).and_return(automator)
      expect(automator).to(
        receive(:pan).with("from", "to", {:duration => 1.0}).and_return(true)
      )

      expect(world.pan("from", "to")).to be_truthy
    end
  end

  context "#pan_coordinates" do
    context "raises an ArgumentError if called with an invalid duration" do
      let(:options) { {} }

      it "raises if duration < 0.5 with UIAutomation" do
        expect(world).to receive(:uia_available?).and_return(true)
        options[:duration] = 0.4

        expect do
          world.pan_coordinates("from", "to", options)
        end.to raise_error ArgumentError, /Invalid duration/
      end

      it "raises if duration <= 0.0 with DeviceAgent" do
        expect(world).to receive(:uia_available?).and_return(false)
        options[:duration] = 0.0

        expect do
          world.pan_coordinates("from", "to", options)
        end.to raise_error ArgumentError, /Invalid duration/
      end
    end

    it "calls the automator #pan method" do
      expect(world).to receive(:launcher).and_return(launcher)
      expect(launcher).to receive(:automator).and_return(automator)
      expect(automator).to(
        receive(:pan_coordinates).with("from", "to", {:duration => 1.0}).and_return(true)
      )

      expect(world.pan_coordinates("from", "to")).to be_truthy
    end
  end

  context "pinch" do
    context "performs the pinch gesture" do
      let(:merged_options) do
        {
          :query => nil,
          :amount => 100,
          :duration => 0.5
        }
      end

      before do
        expect(world).to receive(:launcher).and_return(launcher)
        expect(launcher).to receive(:automator).and_return(automator)
      end

      it "allows :in" do
        expect(automator).to(
          receive(:pinch).with(:in, merged_options).and_return(true)
        )

        expect(world.pinch(:in)).to be_truthy
      end

      it "allows 'in'" do
        expect(automator).to(
          receive(:pinch).with(:in, merged_options).and_return(true)
        )

        expect(world.pinch("in")).to be_truthy
      end

      it "allows :out" do
        expect(automator).to(
          receive(:pinch).with(:out, merged_options).and_return(true)
        )

        expect(world.pinch(:out)).to be_truthy
      end

      it "allows 'out'" do
        expect(automator).to(
          receive(:pinch).with(:out, merged_options).and_return(true)
        )

        expect(world.pinch("out")).to be_truthy
      end
    end

    it "raises an error if in_out argument is invalid" do
      expect do
        world.pinch(:invalid)
      end.to raise_error ArgumentError, /Invalid pinch direction/
    end

    context "validates duration option" do
      let(:options) { {} }

      it "raises if duration < 0.5 with UIAutomation" do
        expect(world).to receive(:uia_available?).and_return(true)
        options[:duration] = 0.4

        expect do
          world.pinch(:in, options)
        end.to raise_error ArgumentError, /Invalid duration/
      end

      it "raises if duration <= 0.0 with DeviceAgent" do
        expect(world).to receive(:uia_available?).and_return(false)
        options[:duration] = 0.0

        expect do
          world.pinch(:in, options)
        end.to raise_error ArgumentError, /Invalid duration/
      end
    end
  end

  context "#flick" do
    it "performs the flick gesture" do
      options = { }
      delta =  {:x => 10, :y => 20}
      merged = {:delta => delta}.merge(options)

      expect(world).to(
        receive(:query_action_with_options).with(:flick, "query", merged)
      ).and_return([:view])

      expect(world.flick("query", delta)).to be == [:view]
    end

    context "validating arguments" do
      it "raises an ArgumentError when passed a nil query" do
        expect do
          world.flick(nil, :left)
        end.to raise_error ArgumentError, /Query argument cannot be nil/
      end
    end
  end

  context "#rotate_home_button_to" do
    let(:position) { :left }

    it "does nothing if status bar orientation is the same as current orientation" do
      expect(world).to receive(:expect_valid_rotate_home_to_arg).with(:left).and_return(:left)
      expect(world).to receive(:status_bar_orientation).and_return(:left)

      expect(world.rotate_home_button_to(:left)).to be == :left
    end

    it "calls out to automator to perform the gesture" do
      expect(world).to receive(:expect_valid_rotate_home_to_arg).with(:left).and_return(:left)
      expect(world).to receive(:status_bar_orientation).and_return(:right)
      expect(world).to receive(:launcher).and_return(launcher)
      expect(launcher).to receive(:automator).and_return(automator)
      expect(automator).to receive(:rotate_home_button_to).with(:left).and_return(:left)

      expect(world.rotate_home_button_to(:left)).to be == :left
    end
  end

  context "#rotate" do
    it "raises an error if direction in not left or right" do
      expect do
        world.rotate(:invalid)
      end.to raise_error(ArgumentError, /to be :left or :right/)
    end

    context "valid argument" do
      before do
        expect(world).to receive(:launcher).and_return(launcher)
        expect(launcher).to receive(:automator).and_return(automator)
      end

      it "rotates right when passed :right" do
        expect(automator).to receive(:rotate).with(:right).and_return :orientation

        expect(world.rotate(:right)).to be == :orientation
      end

      it "rotates right when passed 'right'" do
        expect(automator).to receive(:rotate).with(:right).and_return :orientation

        expect(world.rotate("right")).to be == :orientation
      end

      it "rotates left when passed :left" do
        expect(automator).to receive(:rotate).with(:left).and_return :orientation

        expect(world.rotate(:left)).to be == :orientation
      end

      it "rotates left when passed 'left'" do
        expect(automator).to receive(:rotate).with(:left).and_return :orientation

        expect(world.rotate("left")).to be == :orientation
      end
    end
  end

  context "interacting with the keyboard" do
    before do
      allow(world).to receive(:launcher).and_return(launcher)
      allow(launcher).to receive(:automator).and_return(automator)
    end

    context "#keyboard_enter_char" do

      before do
        expect(world).to receive(:expect_keyboard_visible!).and_return(true)
      end

      it "raises an error if char is not special and is more than a single char" do
        expect(automator).to receive(:char_for_keyboard_action).with("abc").and_return(nil)

        expect do
          world.keyboard_enter_char("abc")
        end.to raise_error ArgumentError, /to be a single character or a special string/
      end

      context "valid character" do

        let(:options) { {:wait_after_char => 0 } }

        it "handles specials characters like 'Delete' and 'Return'" do
          expect(automator).to(
            receive(:char_for_keyboard_action).with("Delete").and_return("del")
          )
          expect(automator).to(
            receive(:enter_char_with_keyboard).with("del").and_return(true)
          )

          expect(world.keyboard_enter_char("Delete", options)).to be == []
        end

        it "handles single characters" do
          expect(automator).to(
            receive(:char_for_keyboard_action).with("a").and_return(nil)
          )
          expect(automator).to(
            receive(:enter_char_with_keyboard).with("a").and_return(true)
          )

          expect(world.keyboard_enter_char("a", options)).to be == []
        end

        it "sleeps after typing the char by default" do
          expect(automator).to(
            receive(:char_for_keyboard_action).with("a").and_return(nil)
          )
          expect(automator).to(
            receive(:enter_char_with_keyboard).with("a").and_return(true)
          )
          expect(Kernel).to receive(:sleep).with(0.05).and_return(true)

          expect(world.keyboard_enter_char("a")).to be == []
        end

        it "merges options" do
          expect(automator).to(
            receive(:char_for_keyboard_action).with("a").and_return(nil)
          )
          expect(automator).to(
            receive(:enter_char_with_keyboard).with("a").and_return(true)
          )
          options[:wait_after_char] = 5.0
          expect(Kernel).to receive(:sleep).with(5.0).and_return(true)

          expect(world.keyboard_enter_char("a", options)).to be == []
        end
      end
    end

    context "#tap_keyboard_action_key" do
      it "asks the automator to tap the action key" do
        expect(world).to receive(:expect_keyboard_visible!).and_return(true)
        expect(automator).to receive(:tap_keyboard_action_key).and_return(:success)

        expect(world.tap_keyboard_action_key).to be == :success
      end
    end

    context "#tap_keyboard_delete_key" do
      it "asks the automator to tap the delete key" do
        expect(world).to receive(:expect_keyboard_visible!).and_return(true)
        expect(automator).to receive(:tap_keyboard_delete_key).and_return(:success)

        expect(world.tap_keyboard_delete_key).to be == :success
      end
    end

    context "#keyboard_enter_text" do

      before do
        expect(world).to receive(:expect_keyboard_visible!).and_return(true)
      end

      it "asks the automator type the text" do
        expect(world).to receive(:text_from_first_responder).and_return("")
        expect(automator).to(
          receive(:enter_text_with_keyboard).with("hello", "").and_return(:success)
        )

        expect(world.keyboard_enter_text("hello")).to be == :success
      end

      it "escapes newlines in existing text" do
        existing = %Q[abc\nabc\n]
        escaped = %Q[abc\\nabc\\n]
        expect(world).to receive(:text_from_first_responder).and_return(existing)
        expect(automator).to(
          receive(:enter_text_with_keyboard).with("hello", escaped).and_return(:success)
        )

        expect(world.keyboard_enter_text("hello")).to be == :success
      end
    end

    context "#enter_text_in" do
      # Punting on some of these tests; the method was not written to be tested.
      it "has a method alias: enter_text" do
        expect(world.respond_to?(:enter_text)).to be_truthy
      end

      it "waits if the options say so"

      it "passes wait options to to wait_for_elements_exist"

      it "raises an error if query finds no match" do
        expect(world).to(
          receive(:wait_for_element_exists).and_raise "Could not find element"
        )

        expect do
          world.enter_text_in("query", "text")
        end.to raise_error RuntimeError, /Could not find element/
      end

      context "query finds a matching element" do

        before do
          expect(world).to receive(:wait_for_element_exists).and_return(true)
          expect(world).to receive(:touch).and_return(true)
          expect(world).to receive(:wait_for_keyboard).and_return(true)
        end

        it "passes options to touch"

        it "raises if keyboard does not appear"

        it "calls keyboard_enter_text when options say so" do
          options = {:use_keyboard => true}
          expect(world).to receive(:keyboard_enter_text).with("text").and_return(:success)

          expect(world.enter_text_in("query", "text", options)).to be == :success
        end

        it "calls fast_enter_text by default" do
          expect(world).to receive(:fast_enter_text).with("text").and_return(:success)

          expect(world.enter_text_in("query", "text")).to be == :success
        end
      end
    end

    context "#fast_enter_text" do
      it "asks the automator to fast enter text" do
        expect(world).to receive(:expect_keyboard_visible!).and_return(true)
        expect(automator).to(
          receive(:fast_enter_text).with("text").and_return(:success)
        )

        expect(world.fast_enter_text("text")).to be == :success
      end
    end

    context "#dismiss_ipad_keyboard" do
      it "raises an error if called on an iPhone or iPad" do
        expect(world).to receive(:device_family_iphone?).and_return(true)
        expect(world).to receive(:screenshot).and_return("path/to/screenshot")
        expect(world).to receive(:embed).and_return(true)

        expect do
          world.dismiss_ipad_keyboard
        end.to raise_error RuntimeError, /There is no Hide Keyboard key on an iPhone/
      end

      it "asks the automator to dismiss the iPad keyboard and waits" do
        expect(world).to receive(:device_family_iphone?).and_return(false)
        expect(world).to receive(:expect_keyboard_visible!).and_return(true)
        expect(world).to receive(:wait_for_no_keyboard).and_return(true)
        expect(automator).to receive(:dismiss_ipad_keyboard).and_return(true)

        expect(world.dismiss_ipad_keyboard).to be == true
      end
    end
  end

  describe "#backdoor" do
    let(:args) do
      {
        :method => :post,
        :path => "backdoor"
      }
    end

    let(:selector) { "myBackdoor:" }
    let(:parameters) do
      {
        :selector => selector,
        :arguments => ["a", "b", "c"]
      }
    end

    describe "raises errors" do
      it "http call fails" do
        class MyHTTPError < RuntimeError ; end
        expect(world).to receive(:http).and_raise MyHTTPError, "My error"

        expect do
          world.backdoor(selector)
        end.to raise_error RuntimeError, /My error/
      end

      it "parsing the response fails" do
        expect(world).to receive(:http).and_return ""
        class MyJSONError < RuntimeError ; end
        expect(world).to receive(:response_body_to_hash).with("").and_raise MyJSONError, "JSON error"

        expect do
          world.backdoor(selector)
        end.to raise_error RuntimeError, /JSON error/
      end

      it "outcome is FAILURE" do
        hash = {
          "outcome" => "FAILURE",
          "reason" => "This is unreasonable",
          "details" => "The sordid details"
        }

        expect(world).to receive(:http).and_return ""
        expect(world).to receive(:response_body_to_hash).with("").and_return(hash)

        expect do
          world.backdoor(selector, "a", "b", "c")
        end.to raise_error RuntimeError, /backdoor call failed/
      end
    end

    it "returns the results key" do
        hash = {
          "outcome" => "SUCCESS",
          "results" => 1
        }

      expect(world).to receive(:http).with(args, parameters).and_return ""
      expect(world).to receive(:response_body_to_hash).with("").and_return hash

      actual = world.backdoor(selector, "a", "b", "c")
      expect(actual).to be == hash["results"]
    end
  end

  describe "send_app_to_background" do
    describe "raises errors" do

      it "raises argument error when seconds < 1.0" do
        expect do
          world.send_app_to_background(0.5)
        end.to raise_error ArgumentError, /must be >= 1.0/
      end

      it "http call fails" do
        class MyHTTPError < RuntimeError ; end
        expect(world).to receive(:http).and_raise MyHTTPError, "My error"

        expect do
          world.send_app_to_background(1.0)
        end.to raise_error RuntimeError, /My error/
      end

      it "parsing the response fails" do
        expect(world).to receive(:http).and_return ""
        class MyJSONError < RuntimeError ; end
        expect(world).to receive(:response_body_to_hash).with("").and_raise MyJSONError, "JSON error"

        expect do
          world.send_app_to_background(1.0)
        end.to raise_error RuntimeError, /JSON error/
      end

      it "outcome is FAILURE" do
        hash = {
          "outcome" => "FAILURE",
          "reason" => "This is unreasonable",
          "details" => "The sordid details"
        }

        expect(world).to receive(:http).and_return ""
        expect(world).to receive(:response_body_to_hash).with("").and_return(hash)

        expect do
          world.send_app_to_background(1.0)
        end.to raise_error RuntimeError, /Could not send app to background:/
      end
    end

    let(:args) { {:method => :post, :path => "suspend"} }
    let(:parameters) { {:duration => 1.0 } }

    it "sets the http parameters correctly" do
      parameters[:duration] = 5.0

      hash = {
        "outcome" => "SUCCESS",
        "results" => 1
      }

      expect(world).to receive(:http).with(args, parameters).and_return ""
      expect(world).to receive(:response_body_to_hash).with("").and_return(hash)

      actual = world.send_app_to_background(5.0)
      expect(actual).to be == hash["results"]
    end

    it "returns the results key" do

      hash = {
        "outcome" => "SUCCESS",
        "results" => 1
      }

      expect(world).to receive(:http).with(args, parameters).and_return ""
      expect(world).to receive(:response_body_to_hash).with("").and_return hash

      actual = world.send_app_to_background(1.0)
      expect(actual).to be == hash["results"]
    end
  end

  describe "console_attach" do
    it "raises an error on the XTC" do
      expect(Calabash::Cucumber::Environment).to receive(:xtc?).and_return(true)

      expect do
        world.console_attach
      end.to raise_error RuntimeError,
      /This method is not available on the Xamarin Test Cloud/
    end

    it "calls launcher#attach" do
      launcher = Calabash::Cucumber::Launcher.new
      strategy = :host
      options = { :uia_strategy => strategy }
      expect(launcher).to receive(:attach).with(options).and_return(launcher)
      expect(Calabash::Cucumber::Environment).to receive(:xtc?).and_return(false)

      actual = world.console_attach(strategy)
      expect(actual).to be == launcher
    end
  end

  describe "shake" do
    describe "raises errors" do

      it "raises argument error when seconds < 0.0" do
        expect do
          world.shake(0.0)
        end.to raise_error ArgumentError, /must be >= 0.0/
      end

      it "http call fails" do
        class MyHTTPError < RuntimeError ; end
        expect(world).to receive(:http).and_raise MyHTTPError, "My error"

        expect do
          world.shake(1.0)
        end.to raise_error RuntimeError, /My error/
      end

      it "parsing the response fails" do
        expect(world).to receive(:http).and_return ""
        class MyJSONError < RuntimeError ; end
        expect(world).to receive(:response_body_to_hash).with("").and_raise MyJSONError, "JSON error"

        expect do
          world.shake(1.0)
        end.to raise_error RuntimeError, /JSON error/
      end

      it "outcome is FAILURE" do
        hash = {
          "outcome" => "FAILURE",
          "reason" => "This is unreasonable",
          "details" => "The sordid details"
        }

        expect(world).to receive(:http).and_return ""
        expect(world).to receive(:response_body_to_hash).with("").and_return(hash)

        expect do
          world.shake(1.0)
        end.to raise_error RuntimeError, /Could not shake the device/
      end
    end

    let(:args) { {:method => :post, :path => "shake"} }
    let(:parameters) { {:duration => 1.0 } }

    it "sets the http parameters correctly" do
      parameters[:duration] = 5.0

      hash = {
        "outcome" => "SUCCESS",
        "results" => 1
      }

      expect(world).to receive(:http).with(args, parameters).and_return ""
      expect(world).to receive(:response_body_to_hash).with("").and_return(hash)

      actual = world.shake(5.0)
      expect(actual).to be == hash["results"]
    end

    it "returns the results key" do

      hash = {
        "outcome" => "SUCCESS",
        "results" => 1
      }

      expect(world).to receive(:http).with(args, parameters).and_return ""
      expect(world).to receive(:response_body_to_hash).with("").and_return hash

      actual = world.shake(1.0)
      expect(actual).to be == hash["results"]
    end
  end

  context "#device_agent" do
    it "raises an error if launcher is nil" do
      expect(Calabash::Cucumber::Launcher).to(
        receive(:launcher_if_used).and_return(nil)
      )
      expect do
        world.device_agent
      end.to raise_error RuntimeError, /There is no launcher/
    end

    it "raises an error if launcher automator is nil" do
      expect(Calabash::Cucumber::Launcher).to(
        receive(:launcher_if_used).and_return(launcher)
      )
      expect(launcher).to receive(:automator).and_return(nil)

      expect do
        world.device_agent
      end.to raise_error RuntimeError, /The launcher is not attached to an automator/
    end

    it "raises an error if launcher.gesture_performer is not device_agent" do
      expect(Calabash::Cucumber::Launcher).to(
        receive(:launcher_if_used).and_return(launcher)
      )
      allow(launcher).to receive(:automator).and_return(automator)
      allow(automator).to receive(:name).and_return(:not_device_agent)

      expect do
        world.device_agent
      end.to raise_error RuntimeError, /The launcher automator is not DeviceAgent/

    end

    context "gesture performer is a DeviceAgent instance" do
      let(:run_loop_client) { "RunLoop::DeviceAgent::Client" }
      let(:device_agent_api) { "DeviceAgent API" }

      before do
        expect(Calabash::Cucumber::Launcher).to(
          receive(:launcher_if_used).and_return(launcher)
        )
        allow(launcher).to receive(:automator).and_return(automator)
        allow(automator).to receive(:name).and_return(:device_agent)
        allow(automator).to receive(:client).and_return(run_loop_client)
      end

      it "raises an error if client is not running" do
        expect(automator).to receive(:running?).and_return(false)

        expect do
          world.device_agent
        end.to raise_error RuntimeError, /The DeviceAgent is not running/
      end

      it "returns the device_agent.client" do
        expect(automator).to receive(:running?).and_return(true)
        expect(Calabash::Cucumber::DeviceAgent).to(
          receive(:new).with(run_loop_client, world).and_return(device_agent_api)
        )

        expect(world.device_agent).to be == device_agent_api
      end
    end
  end

  context "#launcher" do
    it "returns @@launcher" do
      expect(Calabash::Cucumber::Launcher).to receive(:launcher).and_return(launcher)

      expect(world.launcher).to be == launcher
    end

    it "returns nil" do
      expect(Calabash::Cucumber::Launcher).to receive(:launcher).and_return(nil)

      expect(world.launcher).to be == nil
    end
  end

  context "#run_loop" do
    it "returns hash representing a run_loop if one is available" do
      expect(Calabash::Cucumber::Launcher).to receive(:launcher_if_used).and_return(launcher)
      expect(launcher).to receive(:run_loop).and_return({})

      expect(world.run_loop).to be == {}
    end

    it "returns nil if Launcher::@@launcher is nil" do
      expect(Calabash::Cucumber::Launcher).to receive(:launcher_if_used).and_return(nil)

      expect(world.run_loop).to be == nil
    end

    it "returns nil if @@launcher.run_loop is nil" do
      expect(Calabash::Cucumber::Launcher).to receive(:launcher_if_used).and_return(launcher)
      expect(launcher).to receive(:run_loop).and_return(nil)

      expect(world.run_loop).to be == nil
    end
  end

  context "#tail_run_loop_log" do
    let(:path) { "path/to/log.txt" }
    let(:hash) { {:log_file => path} }

    it "raises error if there is not an active run-loop" do
      expect(world).to receive(:run_loop).and_return(nil)

      expect do
        world.tail_run_loop_log
      end.to raise_error RuntimeError,
                         /Unable to tail instruments log because there is no active run-loop/
    end

    it "raises error if there is active run-loop but it is not :instruments based" do
      expect(world).to receive(:run_loop).and_return(hash)
      expect(world).to receive(:launcher).and_return(launcher)
      expect(launcher).to receive(:instruments?).and_return(false)

      expect do
        world.tail_run_loop_log
      end.to raise_error RuntimeError, /Cannot tail a non-instruments run-loop/
    end

    it "opens a Terminal window to tail run-loop log file" do
      expect(world).to receive(:run_loop).at_least(:once).and_return(hash)
      expect(world).to receive(:launcher).and_return(launcher)
      expect(launcher).to receive(:instruments?).and_return(true)
      expect(Calabash::Cucumber::LogTailer).to receive(:tail_in_terminal).with(path).and_return(true)

      expect(world.tail_run_loop_log).to be_truthy
    end
  end

  context "#dump_run_loop_log" do
    let(:path) { File.join(Resources.shared.resources_dir, "run_loop.out") }
    let(:hash) { {:log_file => path} }

    it "raises error if there is not an active run-loop" do
      expect(world).to receive(:run_loop).and_return(nil)

      expect do
        world.dump_run_loop_log
      end.to raise_error RuntimeError,
                         /Unable to dump run-loop log because there is no active run-loop/
    end

    it "raises error if there is an active run-loop but it is not :instruments based" do
      expect(world).to receive(:run_loop).and_return(hash)
      expect(world).to receive(:launcher).and_return(launcher)
      expect(launcher).to receive(:instruments?).and_return(false)

      expect do
        world.dump_run_loop_log
      end.to raise_error RuntimeError, /Cannot dump non-instruments run-loop/
    end

    it "prints the contents of the run-loop log file" do
      expect(world).to receive(:run_loop).at_least(:once).and_return(hash)
      expect(world).to receive(:launcher).and_return(launcher)
      expect(launcher).to receive(:instruments?).and_return(true)

      expect(world.dump_run_loop_log).to be_truthy
    end
  end

  context "#scroll_to_mark" do
    let(:options) do
      {
        :query => "query",
        :animate => :animate,
        :failure_message => "custom failure message"
      }
    end
    let(:success) { ["a non nil result"] }
    let(:failure) { [ nil ] }
    let(:map) { Calabash::Cucumber::Map.new }

    before do
      allow(Calabash::Cucumber::Map).to receive(:map_factory).and_return(map)
      allow(map).to receive(:screenshot).and_return("path/to/screenshot")
    end

    it "raises an ArgumentError if mark is nil" do
      expect do
        world.scroll_to_mark(nil)
      end.to raise_error ArgumentError, /The mark cannot be nil/
    end

    context "validates the :query option" do
      it "raises an ArgumentError if query is nil" do
        expect do
          world.scroll_to_mark(:mark, {:query => nil})
        end.to raise_error ArgumentError, /query option cannot be nil/
      end

      it "raises an ArgumentError if query is nil" do
        expect do
          world.scroll_to_mark(:mark, {:query => ""})
        end.to raise_error ArgumentError, /query option cannot be the empty string/
      end

      it "raises an ArgumentError if query is *" do
        expect do
          world.scroll_to_mark(:mark, {:query => "*"})
        end.to raise_error ArgumentError, /query option cannot be the wildcard/
      end
    end

    context "merges options correctly and asserts results" do
      it "calls map with the correct variables" do
        expect(Calabash::Cucumber::Map).to(
          receive(:map).with("query", :scrollToMark, :mark, :animate).and_return(success)
        )

        actual = world.scroll_to_mark(:mark, options)
        expect(actual).to be == success
      end

      it "fails with the right error message" do
        expect(Calabash::Cucumber::Map).to(
          receive(:map).with("query", :scrollToMark, :mark, :animate).and_return(failure)
        )

        expect do
          world.scroll_to_mark(:mark, options)
        end.to raise_error RuntimeError, /#{options[:failure_message]}/
      end
    end

    it "calls Map with the correct defaults" do
      expect(Calabash::Cucumber::Map).to(
        receive(:map).with("UIScrollView index:0", :scrollToMark, :mark, true).and_return(success)
      )

      actual = world.scroll_to_mark(:mark)
      expect(actual).to be == success
    end

    it "fails with a good default message" do
      expect(Calabash::Cucumber::Map).to(
        receive(:map).with("UIScrollView index:0", :scrollToMark, :mark, true).and_return(failure)
      )

      expect do
        world.scroll_to_mark(:mark)
      end.to raise_error RuntimeError, /Unable to scroll to mark/
    end
  end

  context "#scroll_to_row_with_mark" do
    let(:options) do
      {
        :query => "query",
        :scroll_position => :top,
        :animate => :animate,
        :failure_message => "custom failure message"
      }
    end

    let(:success) { ["a non nil result"] }
    let(:failure) { [ nil ] }
    let(:map) { Calabash::Cucumber::Map.new }

    before do
      allow(Calabash::Cucumber::Map).to receive(:map_factory).and_return(map)
      allow(map).to receive(:screenshot).and_return("path/to/screenshot")
    end

    it "raises an ArgumentError if mark is nil" do
      expect do
        world.scroll_to_row_with_mark(nil)
      end.to raise_error ArgumentError, /The mark cannot be nil/
    end

    context "validates the :query option" do
      it "raises an ArgumentError if query is nil" do
        expect do
          world.scroll_to_row_with_mark(:mark, {:query => nil})
        end.to raise_error ArgumentError, /query option cannot be nil/
      end

      it "raises an ArgumentError if query is nil" do
        expect do
          world.scroll_to_row_with_mark(:mark, {:query => ""})
        end.to raise_error ArgumentError, /query option cannot be the empty string/
      end

      it "raises an ArgumentError if query is *" do
        expect do
          world.scroll_to_row_with_mark(:mark, {:query => "*"})
        end.to raise_error ArgumentError, /query option cannot be the wildcard/
      end
    end

    context "merges options correctly and asserts results" do
      it "calls map with the correct variables" do
        expect(Calabash::Cucumber::Map).to(
          receive(:map).with("query", :scrollToRowWithMark, :mark, :top, :animate).and_return(success)
        )

        actual = world.scroll_to_row_with_mark(:mark, options)
        expect(actual).to be == success
      end

      it "fails with the right error message" do
        expect(Calabash::Cucumber::Map).to(
          receive(:map).with("query", :scrollToRowWithMark, :mark, :top, :animate).and_return(failure)
        )

        expect do
          world.scroll_to_row_with_mark(:mark, options)
        end.to raise_error RuntimeError, /#{options[:failure_message]}/
      end
    end

    it "calls Map with the correct defaults" do
      expect(Calabash::Cucumber::Map).to(
        receive(:map).with("UITableView index:0", :scrollToRowWithMark, :mark, :middle, true).and_return(success)
      )

      actual = world.scroll_to_row_with_mark(:mark)
      expect(actual).to be == success
    end

    it "fails with a good default message" do
      expect(Calabash::Cucumber::Map).to(
        receive(:map).with("UITableView index:0", :scrollToRowWithMark, :mark, :middle, true).and_return(failure)
      )

      expect do
        world.scroll_to_row_with_mark(:mark)
      end.to raise_error RuntimeError, /Unable to scroll to mark/
    end
  end

  context "#scroll_to_collection_view_item" do
    let(:options) do
      {
        :query => "query",
        :scroll_position => :bottom,
        :animate => :animate,
        :failure_message => "custom failure message"
      }
    end

    let(:success) { ["a non nil result"] }
    let(:failure) { [ nil ] }
    let(:map) { Calabash::Cucumber::Map.new }

    before do
      allow(Calabash::Cucumber::Map).to receive(:map_factory).and_return(map)
      allow(map).to receive(:screenshot).and_return("path/to/screenshot")
    end

    context "validates the :query option" do
      it "raises an ArgumentError if query is nil" do
        expect do
          world.scroll_to_collection_view_item(1, 1, {:query => nil})
        end.to raise_error ArgumentError, /query option cannot be nil/
      end

      it "raises an ArgumentError if query is nil" do
        expect do
          world.scroll_to_collection_view_item(1, 1, {:query => ""})
        end.to raise_error ArgumentError, /query option cannot be the empty string/
      end

      it "raises an ArgumentError if query is *" do
        expect do
          world.scroll_to_collection_view_item(1, 1, {:query => "*"})
        end.to raise_error ArgumentError, /query option cannot be the wildcard/
      end
    end

    context "validates item and section index arguments" do
      it "raises an ArgumentError if item index < 0" do
        expect do
          world.scroll_to_collection_view_item(-1, 0)
        end.to raise_error ArgumentError, /Invalid item index/
      end

      it "raises an ArgumentError if section index < 0" do
        expect do
          world.scroll_to_collection_view_item(0, -1)
        end.to raise_error ArgumentError, /Invalid section index/
      end
    end

    context "validates the scroll position" do
      it "raises an error if :scroll_position is invalid" do
        options[:scroll_position] = :invalid

        expect do
          world.scroll_to_collection_view_item(0, 1, options)
        end.to raise_error ArgumentError, /Invalid :scroll_position option/
      end
    end

    context "merges options correctly and asserts results" do
      it "calls map with the correct variables" do
        expect(Calabash::Cucumber::Map).to(
          receive(:map).with("query", :collectionViewScroll,
                             0, 1, :bottom, :animate).and_return(success)
        )

        actual = world.scroll_to_collection_view_item(0, 1, options)
        expect(actual).to be == success
      end

      it "fails with the right error message" do
        expect(Calabash::Cucumber::Map).to(
          receive(:map).with("query", :collectionViewScroll,
                             0, 1, :bottom, :animate).and_return(failure)
        )

        expect do
          world.scroll_to_collection_view_item(0, 1, options)
        end.to raise_error RuntimeError, /#{options[:failure_message]}/
      end
    end

    it "calls Map with the correct defaults" do
      expect(Calabash::Cucumber::Map).to(
        receive(:map).with("UICollectionView index:0", :collectionViewScroll,
                           0, 1, :top, true).and_return(success)
      )

      actual = world.scroll_to_collection_view_item(0, 1)
      expect(actual).to be == success
    end

    it "fails with a good default message" do
      expect(Calabash::Cucumber::Map).to(
        receive(:map).with("UICollectionView index:0", :collectionViewScroll,
                           0, 1, :top, true).and_return(failure)
      )

      expect do
        world.scroll_to_collection_view_item(0, 1)
      end.to raise_error RuntimeError, /Unable to scroll to item/
    end
  end

  context "#scroll_to_collection_view_item_with_mark" do
    let(:options) do
      {
        :query => "query",
        :scroll_position => :bottom,
        :animate => :animate,
        :failure_message => "custom failure message"
      }
    end

    let(:success) { ["a non nil result"] }
    let(:failure) { [ nil ] }
    let(:map) { Calabash::Cucumber::Map.new }

    before do
      allow(Calabash::Cucumber::Map).to receive(:map_factory).and_return(map)
      allow(map).to receive(:screenshot).and_return("path/to/screenshot")
    end

    it "raises an ArgumentError if mark is nil" do
      expect do
        world.scroll_to_collection_view_item_with_mark(nil)
      end.to raise_error ArgumentError, /The mark cannot be nil/
    end

    context "validates the :query option" do
      it "raises an ArgumentError if query is nil" do
        expect do
          world.scroll_to_collection_view_item_with_mark(:mark, {:query => nil})
        end.to raise_error ArgumentError, /query option cannot be nil/
      end

      it "raises an ArgumentError if query is nil" do
        expect do
          world.scroll_to_collection_view_item_with_mark(:mark, {:query => ""})
        end.to raise_error ArgumentError, /query option cannot be the empty string/
      end

      it "raises an ArgumentError if query is *" do
        expect do
          world.scroll_to_collection_view_item_with_mark(:mark, {:query => "*"})
        end.to raise_error ArgumentError, /query option cannot be the wildcard/
      end
    end

    context "validates the scroll position" do
      it "raises an error if :scroll_position is invalid" do
        options[:scroll_position] = :invalid

        expect do
          world.scroll_to_collection_view_item_with_mark(:mark, options)
        end.to raise_error ArgumentError, /Invalid :scroll_position option/
      end
    end

    context "merges options correctly and asserts results" do
      it "calls map with the correct variables" do
        expect(Calabash::Cucumber::Map).to(
          receive(:map).with("query", :collectionViewScrollToItemWithMark,
                             :mark, :bottom, :animate).and_return(success)
        )

        actual = world.scroll_to_collection_view_item_with_mark(:mark, options)
        expect(actual).to be == success
      end

      it "fails with the right error message" do
        expect(Calabash::Cucumber::Map).to(
          receive(:map).with("query", :collectionViewScrollToItemWithMark,
                             :mark, :bottom, :animate).and_return(failure)
        )

        expect do
          world.scroll_to_collection_view_item_with_mark(:mark, options)
        end.to raise_error RuntimeError, /#{options[:failure_message]}/
      end
    end

    it "calls Map with the correct defaults" do
      expect(Calabash::Cucumber::Map).to(
        receive(:map).with("UICollectionView index:0", :collectionViewScrollToItemWithMark,
                           :mark, :top, true).and_return(success)
      )

      actual = world.scroll_to_collection_view_item_with_mark(:mark)
      expect(actual).to be == success
    end

    it "fails with a good default message" do
      expect(Calabash::Cucumber::Map).to(
        receive(:map).with("UICollectionView index:0", :collectionViewScrollToItemWithMark,
                           :mark, :top, true).and_return(failure)
      )

      expect do
        world.scroll_to_collection_view_item_with_mark(:mark)
      end.to raise_error RuntimeError, /Unable to scroll to item/
    end
  end
end
