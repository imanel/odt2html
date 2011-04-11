module ODT2HTML
  # Represents a CSS declaration block; a sequence of zero
  # or more +Declaration+s.
  class DeclarationBlock < Array
    attr_accessor( :block_used )

    def initialize(*arglist)
      if (arglist[0].kind_of? DeclarationBlock) then
        dblock = arglist[0]
        super( 0 )
        dblock.each do |item|
          push Declaration.new( item.property, item.value )
        end
      else
        super
      end
      @block_used = false
    end

    def has_top_border?
    result = detect {|item| item.property =~ /border(-top)?/}
      return (result != nil) ? true : nil
    end

    def to_s
      result = "{\n"
      sort{|a,b| a.property <=> b.property }.each { |item|
        result << "\t#{item.property}: #{item.value};\n"
      }
      result << "}\n"
      return result
    end

  end
end