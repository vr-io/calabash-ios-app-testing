require "cucumber/formatter/html"
require "uri"
require "pathname"

# @!visibility private
module Calabash
  # @!visibility private
  module Formatters
    # @!visibility private
    class Html < ::Cucumber::Formatter::Html
      # @!visibility private
      def embed_image(src, label)
        if _output_relative? && _relative_uri?(src)
          output_dir = Pathname.new(File.dirname(@io.path))
          src_path = Pathname.new(src)
          embed_relative_path = src_path.relative_path_from(output_dir)
          super(embed_relative_path.to_s, label)
        else
          super(src, label)
        end
      end

      # @!visibility private
      def _relative_uri?(src)
        uri = URI.parse(src)
        return false if uri.scheme
        not Pathname.new(src).absolute?
      end

      # @!visibility private
      def _output_relative?
        if @io.is_a?(File)
          path = @io.path
          _relative_uri?(path)
        end
      end
    end
  end
end

