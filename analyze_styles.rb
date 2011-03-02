require 'rexml/document'
require 'rexml/xpath'
require 'style_classes'

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

class ODT_to_XHTML

	def analyze_styles_xml
		
		#
		#	Get the namespaces from the root element; populate the
		# dynamic instance variable names and the namespace hash from them.
		#
		get_namespaces
		
		create_dispatch_table
		
		#	handle default styles; attach to the body
		@doc.root.elements.each(
			"#{@office_ns}:styles/#{@style_ns}:default-style")  do |el|
			if (el.attribute("#{@style_ns}:family").value == "paragraph") then
				process_style( "body",
					el.elements["#{@style_ns}:paragraph-properties"])
				process_style( "body",
					el.elements["#{@style_ns}:text-properties"])
			end
		end
		
		@doc.root.elements.each(
			"#{@office_ns}:styles/#{@style_ns}:style") do |el|
			process_style_style( el )
		end
		
		@doc.root.elements.each(
			"#{@office_ns}:styles/#{@text_ns}:list-style") do |el|
			process_text_list_style( el )		
		end

	end
	
	#
	# Create the <tt>@style_dispatch</tt> hash by substituting the
	# <tt>@valid_style</tt> array entries with their appropriate prefix
	#
	def create_dispatch_table
		i = 0;
		while (i < @valid_style.length) do
			style_name = @valid_style[i].sub(/^([^:]+)/) { |pfx|
				@nshash[pfx]
			}
			if (@valid_style[i].index("*") != nil) then
				style_name = style_name.sub(/.$/, "" )
				@style_dispatch[style_name] = @valid_style[i+1]
				i+=1
			else
				@style_dispatch[style_name] = "process_normal_style_attr"
			end	
			i+=1
		end
	end

	#
	#	Handle a <style:foo-properties> element
	#
	def process_style( class_name, style_element )
		if (style_element != nil) then
			style_element.attributes.each_attribute do |attr|
				if (@style_dispatch.has_key?(attr.expanded_name)) then
					self.send( @style_dispatch[attr.expanded_name], class_name,
						attr.name, attr.value )
				end
			end
		end
	end

	#
	#	Handle a <style:style> element
	#
	def process_style_style( element )
		style_name = element.attribute("#{@style_ns}:name").value.gsub(/\./, "_");
		parent_name = element.attribute("#{@style_ns}:parent-style-name");
		if (parent_name) then
			parent_name = parent_name.value.gsub(/\./,"_")
			if (@style_info[parent_name]) then
				@style_info[style_name] = DeclarationBlock.new(
					@style_info[parent_name] )
			end
		elsif (@style_info[style_name] == nil) then
			@style_info[style_name] = DeclarationBlock.new( )
		end
		
		element.elements.each do |child|
			process_style( style_name, child )
		end
	end

	#	The font-name attribute changes to font-family in CSS
	def process_font_name( selector, property, value )
		process_normal_style_attr(selector, "font-family", value)	
	end
	
	#	<tt>text-align:end</tt> becomes <tt>text-align:right</tt>
	#	and <tt>text-align:start</tt> becomes <tt>text-align:left</tt>
	#	in CSS.
	def process_text_align( selector, property, value )
		value = "right" if (value == "end")
		value = "left" if (value == "start")
		process_normal_style_attr( selector, property, value )
	end
	
	#	<tt>style:column-width</tt> becomes <tt>width</tt>
	#
	def process_column_width( selector, property, value )
		process_normal_style_attr( selector, "width", value )
	end
	
	#	<tt>style:text-underline-style</tt> becomes <tt>text-decoration</tt>
	def process_underline_style( selector, property, value )
		process_normal_style_attr( selector, "text-decoration", 
			(value == "none") ? "none" : "underline" )
	end

	#
	#	The <tt>style:text-position</tt> attribute gives whitespace-separated
	#	distance above or below baseline and a scaling factor as percentages.
	#	If the distance is not 0%, then we have to process as sup/sub;
	#	otherwise, don't touch.
	def process_style_text_position( selector, property, value )
		data = value.split(' ')
		if (data[0] != "0%") then
			process_normal_style_attr( selector, "vertical-align", data[0] )
			process_normal_style_attr( selector, "font-size", data[1] )
		end
	end

	#
	#	If the style hasn't been registered yet, create a new array
	#	with the style property and value.
	#
	#	If the style has been registered, and the property name is a duplicate,
	#	supplant the old property value with the new one.
	#
	#	If the style has been registered, and the property is a new one,
	#	push the property and value onto the array.
	#
	def process_normal_style_attr( selector, property, value )
		if (@style_info[selector] == nil) then
			@style_info[selector] = DeclarationBlock.new( )
			@style_info[selector].push Declaration.new(property, value)
		else
			found = @style_info[selector].find { |obj|
				obj.property == property }
			if (found != nil) then
				found.value = value
			else
				@style_info[selector].push Declaration.new(property, value)
			end
		end
	end
	
	def style_to_s( selector )
		str = "." + selector + @style_info[selector].to_s
		return str
	end	
end
