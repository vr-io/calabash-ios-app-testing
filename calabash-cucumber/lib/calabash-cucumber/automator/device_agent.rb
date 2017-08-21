# @!visibility private
module Calabash
  module Cucumber
    module Automator

      require "calabash-cucumber/automator/automator"

      # @!visibility private
      class DeviceAgent < Calabash::Cucumber::Automator::Automator

        require "run_loop"
        require "calabash-cucumber/map"

        require "calabash-cucumber/query_helpers"
        include Calabash::Cucumber::QueryHelpers

        require "calabash-cucumber/status_bar_helpers"
        include Calabash::Cucumber::StatusBarHelpers

        require "calabash-cucumber/rotation_helpers"
        include Calabash::Cucumber::RotationHelpers

        require "calabash-cucumber/environment_helpers"
        include Calabash::Cucumber::EnvironmentHelpers

        require "calabash-cucumber/automator/coordinates"

        # @!visibility private
        def self.expect_valid_args(args)
          if args.nil?
            raise ArgumentError, "Expected args to be a non-nil Array"
          end

          if !args.is_a?(Array)
            raise ArgumentError, %Q[Expected args to be an Array, found:

args = #{args}

]
          end

          if args.count != 1
            raise(ArgumentError,
                  %Q[Expected args to be an Array with one element, found:

args = #{args}

])
          end

          if !args[0].is_a?(RunLoop::DeviceAgent::Client)
            raise(ArgumentError, %Q[
Expected first element of args to be a RunLoop::DeviceAgent::Client instance, found:
args[0] = #{args[0]}])
          end

          true
        end

        attr_reader :client

        # @!visibility private
        def initialize(*args)
          DeviceAgent.expect_valid_args(args)
          @client = args[0]
        end

        # @!visibility private
        def name
          :device_agent
        end

        # @!visibility private
        def stop
          client.send(:shutdown)
        end

        # @!visibility private
        def running?
          client.send(:running?)
        end

        # @!visibility private
        def session_delete
          client.send(:session_delete)
        end

        # @!visibility private
        def touch(options)
          hash = query_for_coordinates(options)

          client.perform_coordinate_gesture("touch",
                                            hash[:coordinates][:x],
                                            hash[:coordinates][:y])
          [hash[:view]]
        end

        # @!visibility private
        def double_tap(options)
          hash = query_for_coordinates(options)
          client.perform_coordinate_gesture("double_tap",
                                            hash[:coordinates][:x],
                                            hash[:coordinates][:y])
          [hash[:view]]
        end

        # @!visibility private
        def two_finger_tap(options)
          hash = query_for_coordinates(options)
          client.perform_coordinate_gesture("two_finger_tap",
                                            hash[:coordinates][:x],
                                            hash[:coordinates][:y])
          [hash[:view]]
        end

        # @!visibility private
        def touch_hold(options)
          hash = query_for_coordinates(options)

          duration = options[:duration] || 3
          client.perform_coordinate_gesture("touch",
                                            hash[:coordinates][:x],
                                            hash[:coordinates][:y],
                                            {:duration => duration})
          [hash[:view]]
        end

        # @!visibility private
        def swipe(options)
          dupped_options = options.dup

          if dupped_options[:query].nil?
            element = element_for_device_screen
            from_point = point_from(element, options)
          else
            hash = query_for_coordinates(dupped_options)
            from_point = hash[:coordinates]
            element = hash[:view]
          end

          # DeviceAgent does not understand the :force. Does anyone?
          force = dupped_options[:force]
          case force
            when :strong
              duration = 0.2
            when :normal
              duration = 0.4
            when :light
              duration = 0.7
            else
              # Caller is responsible for validating the :force option.
              duration = 0.5
          end

          gesture_options = {
            :duration => duration
          }

          direction = dupped_options[:direction]
          to_point = Coordinates.end_point_for_swipe(direction, element, force)
          client.pan_between_coordinates(from_point, to_point, gesture_options)
          [element]
        end

        # @!visibility private
        def pinch(in_out, options)
          dupped_options = options.dup

          if dupped_options[:query].nil?
            element = element_for_device_screen
            coordinates = point_from(element, options)
          else
            hash = query_for_coordinates(dupped_options)
            element = hash[:view]
            coordinates = hash[:coordinates]
          end

          in_out = in_out.to_s
          duration = dupped_options[:duration]
          amount = dupped_options[:amount]

          gesture_options = {
            :pinch_direction => in_out,
            :amount => amount,
            :duration => duration
          }

          client.perform_coordinate_gesture("pinch",
                                            coordinates[:x],
                                            coordinates[:y],
                                            gesture_options)

          [element]
        end

        # @!visibility private
        def pan(from_query, to_query, options)
          dupped_options = options.dup

          dupped_options[:query] = from_query
          from_hash = query_for_coordinates(dupped_options)
          from_point = from_hash[:coordinates]

          dupped_options[:query] = to_query
          to_hash = query_for_coordinates(dupped_options)
          to_point = to_hash[:coordinates]

          gesture_options = {
            :duration => dupped_options[:duration]
          }

          client.pan_between_coordinates(from_point, to_point,
                                         gesture_options)

          [from_hash[:view], to_hash[:view]]
        end

        # @!visibility private
        def pan_coordinates(from_point, to_point, options)

          gesture_options = {
            :duration => options[:duration]
          }

          client.pan_between_coordinates(from_point, to_point,
                                         gesture_options)
          [first_element_for_query("*")]
        end

        # @!visibility private
        def flick(options)
          gesture_options = {
            duration: 0.2
          }

          delta = options[:delta]

          # The UIA deltas are too small.
          scaled_delta = {
            :x => delta[:x] * 2.0,
            :y => delta[:y] * 2.0
          }

          hash = query_for_coordinates(options)
          view = hash[:view]

          start_point = point_from(view)
          end_point = point_from(view, {:offset => scaled_delta})

          client.pan_between_coordinates(start_point,
                                         end_point,
                                         gesture_options)
          [view]
        end

        # @!visibility private
        def enter_text_with_keyboard(string, options={})
          client.enter_text_without_keyboard_check(string)
        end

        # @!visibility private
        def enter_char_with_keyboard(char)
          client.enter_text_without_keyboard_check(char)
        end

        # @!visibility private
        def char_for_keyboard_action(action_key)
          SPECIAL_ACTION_CHARS[action_key]
        end

        # @!visibility private
        def tap_keyboard_action_key
          mark = mark_for_return_key_of_first_responder
          if mark
            begin
              # The underlying query for coordinates always expects results.
              value = client.touch({type: "Button", marked: mark})
              return value
            rescue RuntimeError => _
              RunLoop.log_debug("Cannot find mark '#{mark}' with query; will send a newline")
            end
          else
            RunLoop.log_debug("Cannot find keyboard return key type; sending a newline")
          end

          code = char_for_keyboard_action("Return")
          client.enter_text_without_keyboard_check(code)
        end

        # @!visibility private
        def tap_keyboard_delete_key
          client.touch({marked: "delete"})
        end

        # @!visibility private
        def fast_enter_text(text)
          client.enter_text_without_keyboard_check(text)
        end

        # @!visibility private
        #
        # Stable across different keyboard languages.
        def dismiss_ipad_keyboard
          client.touch({marked: "Hide keyboard"})
        end

        # @!visibility private
        def rotate(direction)
          # Caller is responsible for normalizing and verifying direction.
          current_orientation = status_bar_orientation.to_sym
          key = orientation_key(direction, current_orientation)
          position = orientation_for_key(key)
          rotate_home_button_to(position)
        end

        # @!visibility private
        def rotate_home_button_to(position)
          # Caller is responsible for normalizing and verifying position.
          client.rotate_home_button_to(position)
          status_bar_orientation.to_sym
        end

        private

        # @!visibility private
        #
        # Calls #point_from which applies any :offset supplied in the options.
        def query_for_coordinates(options)
          uiquery = options[:query]

          if uiquery.nil?
            offset = options[:offset]

            if offset && offset[:x] && offset[:y]
              {
                :coordinates => offset,
                :view => offset
              }
            else
              raise ArgumentError, %Q[
If query is nil, there must be a valid offset in the options.

Expected: options[:offset] = {:x => NUMERIC, :y => NUMERIC}
  Actual: options[:offset] = #{offset ? offset : "nil"}

              ]
            end
          else

            first_element = first_element_for_query(uiquery)

            if first_element.nil?
              msg = %Q[
Could not find any views with query:

  #{uiquery}

Make sure your query returns at least one view.

]
              Calabash::Cucumber::Map.new.screenshot_and_raise(msg)
            else
              {
                :coordinates => point_from(first_element, options),
                :view => first_element
              }
            end
          end
        end

        # @!visibility private
        def first_element_for_query(uiquery)

          if uiquery.nil?
            raise ArgumentError, "Query cannot be nil"
          end

          # Will raise if response "outcome" is not SUCCESS
          results = Calabash::Cucumber::Map.raw_map(uiquery, :query)["results"]

          if results.empty?
            nil
          else
            results[0]
          end
        end

        # @!visibility private
        def element_for_device_screen
          screen_dimensions = device.screen_dimensions

          scale = screen_dimensions[:scale]
          height = (screen_dimensions[:height]/scale).to_i
          center_y = (height/2)
          width = (screen_dimensions[:width]/scale).to_i
          center_x = (width/2)

          {
            "screen" => true,
            "rect" => {
              "height" => height,
              "width" => width,
              "center_x" => center_x,
              "center_y" => center_y
            }
          }
        end

        # @!visibility private
        #
        # Don't change the double quotes.
        SPECIAL_ACTION_CHARS = {
          "Delete" => "\b",
          "Return" => "\n"
        }.freeze

        # @!visibility private
        #
        # Keys are from the UIReturnKeyType enum.
        #
        # The values are localization independent identifiers - these are
        # stable across localizations and keyboard languages.  The exception is
        # Continue which is not stable.
        RETURN_KEY_TYPE = {
          0 => "Return",
          1 => "Go",
          2 => "Google",
          # Needs special physical device vs simulator handling.
          3 => "Join",
          4 => "Next",
          5 => "Route",
          6 => "Search",
          7 => "Send",
          8 => "Yahoo",
          9 => "Done",
          10 => "Emergency call",
          # https://xamarin.atlassian.net/browse/TCFW-344
          # Localized!!! Apple bug.
          11 => "Continue"
        }.freeze

        # @!visibility private
        def mark_for_return_key_type(number)
          # https://xamarin.atlassian.net/browse/TCFW-361
          value = RETURN_KEY_TYPE[number]
          if value == "Join" && !simulator?
            "Join:"
          else
            value
          end
        end

        # @!visibility private
        def return_key_type_of_first_responder

          query = "* isFirstResponder:1"
          raw = Calabash::Cucumber::Map.raw_map(query, :query, :returnKeyType)
          elements = raw["results"]
          return nil if elements.count == 0

          return_key_type = elements[0]

          # first responder did not respond to :text selector
          if return_key_type == "*****"
            RunLoop.log_debug("First responder does not respond to :returnKeyType")
            return nil
          end

          if return_key_type.nil?
            RunLoop.log_debug("First responder has nil :returnKeyType")
            return nil
          end

          return_key_type
        end

        # @!visibility private
        def mark_for_return_key_of_first_responder
          number = return_key_type_of_first_responder
          mark_for_return_key_type(number)
        end
      end
    end
  end
end
