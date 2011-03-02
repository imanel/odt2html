=begin rdoc
This class represents a CSS declaration; a
property/value pair
=end
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

=begin rdoc
Represents a CSS declaration block; a sequence of zero
or more +Declaration+s.
=end
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
    each { |item|
      result << "\t#{item.property}: #{item.value};\n"
    }
    result << "}\n"
    return result
  end

end
