require 'txgh'

module Txbr
  class StringsManifest
    include Enumerable

    def initialize
      @strings ||= {}
    end

    # prefix: the value specified in the connected_content "save" option
    #
    # path: an array of path strings, eg ['foo', 'bar']. The whole path
    # is the prefix plus the path, eg. ['prefix', 'foo', 'bar'], which
    # is present in the Liquid template as {{prefix.foo.bar}}.
    #
    # value: the value to associate with this key
    def add(prefix, path, value)
      root = @strings[prefix] ||= {}

      root = path[0...-1].inject(root) do |ret, key|
        ret[key] ||= {}
      end

      root[path.last] = value
    end

    def merge(other_manifest)
      self.class.new.tap do |new_manifest|
        new_manifest.merge!(self)
        new_manifest.merge!(other_manifest)
      end
    end

    def merge!(other_manifest)
      other_manifest.prefixes.each do |prefix|
        other_manifest.each_string(prefix) do |path, value|
          add(prefix, path, value)
        end
      end
    end

    def to_h
      @strings
    end

    def each(prefix, &block)
      return to_enum(__method__, prefix) unless block_given?
      each_helper(@strings[prefix], [], &block)
    end

    def prefixes
      @strings.keys
    end

    alias each_string each

    private

    def each_helper(root, path, &block)
      case root
        when Hash
          root.each_pair do |key, child|
            each_helper(child, path + [key], &block)
          end

        else
          yield path, root
      end
    end
  end
end
