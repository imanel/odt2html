#    This program converts OpenDocument text files to XHTML.
#    Copyright (C) 2006 J. David Eisenberg
#
#    This library is free software; you can redistribute it and/or
#    modify it under the terms of the GNU Lesser General Public
#    License as published by the Free Software Foundation; either
#    version 2.1 of the License, or (at your option) any later version.
#
#    This library is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#    Lesser General Public License for more details.
#
#    You should have received a copy of the GNU Lesser General Public
#    License along with this library; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#	
#	Author: J. David Eisenberg
#	Contact: catcode@catcode.com

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
