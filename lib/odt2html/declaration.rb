module ODT2HTML
  # This class represents a CSS declaration; a
  # property/value pair
  class Declaration
    attr_accessor( :property, :value )
    def initialize( property=nil, value=nil )
      @property = property
      @value = value
    end

    def to_s
      return "#{property}: #{value}"
    end
  end
end
