require 'rexml/document'
require 'rexml/xpath'

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

	def analyze_content_xml
		#
		#	Get the namespaces from the root element; populate the
		# dynamic instance variable names and the namespace hash from them.
		#
		get_namespaces
		
		create_dispatch_table
		
		#	handle style:style elements
		@doc.root.elements.each(
			"#{@office_ns}:automatic-styles/#{@style_ns}:style") do |el|
			process_style_style( el )
		end

		#	handle text:list-style elements
		@doc.root.elements.each(
			"#{@office_ns}:automatic-styles/#{@text_ns}:list-style") do |el|
			process_text_list_style( el )		
		end

		@doc.root.elements.each(
		"#{@office_ns}:body/#{@office_ns}:text") do |item|
			process_children( item, @body )
		end

	end

	#	Process an element's children
	#	node: the context node
	#	output_node: the node to which to add the children
	#	xpath_expr: which children to process (default is all)
	#	
	#	Algorithm:
	#	If the node is a text node, output to the destination.
	#	If it's an element, munge its name into 
	#	<tt>process_prefix_elementname</tt>. If that method exists,
	#	call it to handle the element. Otherwise, process this node's
	#	children recursively.
	#
	def process_children( node, output_node, xpath_expr="node()" )
		REXML::XPath.each( node, xpath_expr ) do |item|
			if (item.kind_of?(REXML::Element)) then
				str = "process_" + @namespace_urn[item.namespace] + "_" +
					item.name.tr_s(":-", "__")
				if ODT_to_XHTML.method_defined?( str ) then
					self.send( str, item, output_node )
				else
					process_children(item, output_node)
				end
			elsif (item.kind_of?(REXML::Text) && !item.value.match(/^\s*$/))
				output_node.add_text(item.value)
			end
		end
		#
		#	If it's empty, add a null string to force a begin and end
		#	tag to be generated
		if (!output_node.has_elements? && !output_node.has_text?) then
			output_node.add_text("")
		end
	end

	#
	#	Paragraphs are processed as <tt>&lt;div&gt;</tt> elements.
	#	A <tt>&lt;text:p&gt;</tt> with no children will generate
	#	a <tt>&lt;br /&gt;</tt>.
	def process_text_p( element, output_node )
		style_name = register_style( element )
		
		# always include class attribute
		attr_hash = {"class" => style_name}
		
		#	If this paragraph has the same style as the previous one,
		#	and a top border, and doesn't have style:join-border set to false
		#	then eliminate the top border to merge it with previous paragraph
		if (style_name != nil && @previous_para_style == style_name) then
			if (@style_info[style_name].has_top_border? && 
				element.attribute_value("#{@style_ns}:join-border") !=
				false) then
				attr_hash["style"] = "border-top: none"
				modify_style_attribute( @previous_para,
					"border-bottom", "none")
			end
		end
		para  = emit_element( output_node, "div", attr_hash )
		@previous_para_style = style_name
		@previous_para = para
		if (element.has_elements? || element.has_text?) then
			process_children( element, para )
		else
			para.add_element("br")
		end
	end

	#
	#	Headings are processed as <tt>&lt;h<i>n</i>&gt;</tt> elements.
	#	The heading level comes from the <tt>text:outline-level</tt>
	#	attribute, with a maximum of 6.
	def process_text_h( element, output_node )
		style_name = register_style( element )
		level = element.attribute("#{@text_ns}:outline-level").value.to_i
		if (level > 6) then
			level = 6
		end
		heading = emit_element( output_node, "h" + level.to_s, {"class" => style_name} )
		process_children( element, heading )
	end

	#	Text spans cannot produce a newline after their
	#	opening tag, so the extra <tt>""</tt> parameter is
	#	passed to <tt>emit_start_tag</tt>
	def process_text_span( element, output_node )
		style_name = register_style( element )
		span = emit_element( output_node, "span", {"class" => style_name} )
		process_children( element, span )
	end

	def process_text_tab( element, output_node )
		output_node.add_text( " " )
	end
	
	def process_text_s( element, output_node )
		output_node.add_text( " " )
	end

	def process_text_a( element, output_node )
		style_name = register_style( element )
		href = element.attribute("#{@xlink_ns}:href").value
		link = emit_element( output_node, "a",
			{"class" => style_name, "href" => href} )
		process_children( element, link )
	end
	
	def process_text_bookmark( element, output_node )
		process_text_bookmark_start( element, output_node )
	end

	def process_text_bookmark_start( element, output_node )
		style_name = register_style( element )
		the_name = element.attribute("#{@text_ns}:name").value;
		anchor = emit_element( output_node, "a",
			{"class" => style_name, "name" => the_name} )
		anchor.add_text("");
	end	

	def process_text_list( element, output_node )
		# determine the level
		tag = "ul"
		level = REXML::XPath.match( element, "ancestor::#{@text_ns}:list" ).size + 1
		if (level == 1) then
			style_name = element.attribute("#{@text_ns}:style-name")
		else
			style_name = REXML::XPath.match( element,
				"ancestor::#{@text_ns}:list[last()]/@#{@text_ns}:style-name" )[0]
		end

		if (style_name != nil) then
			style_name = style_name.value + "_" + level.to_s
			style_name = style_name.tr_s('.','_')
			@style_info[style_name].block_used = true
			
			#
			#	Determine if this is a numbered or bulleted list
			found = @style_info[style_name].find { |obj|
				obj.property == "list-style-type" }
			if (found) then
				if (!found.value.match(/disc|circle|square/)) then
					tag="ol"
				end	
			end
		end
		list_el = emit_element( output_node, tag, {"class" => style_name} )
		process_children(element, list_el)
	end
	
	#
	#	List items are easy; just put the children inside
	#	a <tt>&lt;li&gt;</tt> <tt>&lt;/li&gt;</tt> pair.
	#
	def process_text_list_item( element, output_node )
		style_name = register_style( element )
		item = emit_element( output_node, "li", {"class" => style_name} )
		process_children( element, item )
	end

	def process_table_table( element, output_node )
		style_name = register_style( element );
		table_el = emit_element(output_node, "table", {"class" => style_name,
		 "cellpadding" => "0", "cellspacing" => "0"} )
		process_children( element, table_el, "#{@table_ns}:table-column" )
		if (REXML::XPath.match( element, "#{@table_ns}:table-header-rows" )) then
			thead = emit_element( table_el, "thead" )
			process_children( element, thead, "#{@table_ns}:table-header-rows/#{@table_ns}:table-row" )
		end
		tbody = emit_element( table_el, "tbody" )
		process_children( element, tbody, "#{@table_ns}:table-row" )
	end
	
	def process_table_table_column( element, output_node )
		style_name = register_style(element)
		span = element.attribute("#{@table_ns}:number-columns-repeated")
		if (span != nil) then
			span = span.value
		end
		emit_element( output_node, "col", {"class" => style_name, "span" => span} )
	end

	def process_table_table_row( element, output_node )
		style_name = register_style( element );
		tr = emit_element( output_node, "tr", {"class" => style_name} )
		process_children( element, tr, "#{@table_ns}:table-cell" )
	end

	def process_table_table_cell( element, output_node )
		attr_hash = Hash.new
		style_name = register_style( element );
		if (style_name != nil) then
			attr_hash["class"] = style_name
		end
		repeat = 1;
		attr = element.attribute("#{@table_ns}:number-columns-repeated")
		if (attr != nil) then
			repeat = attr.value.to_i
		end
		attr = element.attribute("#{@table_ns}:number-columns-spanned")
		if (attr != nil) then
			attr_hash["colspan"] = attr.value
		end
		attr = element.attribute("#{@table_ns}:number-rows-spanned")
		if (attr != nil) then
			attr_hash["rowspan"] = attr.value
		end
		(1..repeat).each do |i|
			td = emit_element( output_node, "td", attr_hash )
			process_children( element, td )
		end
	end

	#
	#	Return the style name for this element, with periods
	#	changed to underscores to make it valid CSS.
	#
	#	Side effect: registers this style as "having been used"
	#	in the document
	#
	def register_style( element )
		# get namespace prefix for this element
		style_name = element.attribute("#{element.prefix}:style-name");
		if (style_name != nil) then
			style_name = style_name.value.tr_s('.','_')
			if (@style_info[style_name] != nil) then
				@style_info[style_name].block_used = true
			end
		end
		return style_name
	end

	#
	#	Create styles for each level of a <tt>&lt;text:list-style&gt;</tt>
	#	element. For bulleted lists, it sets the bullet type by indexing
	#	into the <tt>marker</tt> array;	for numbered lists, it uses the
	#	<tt>numbering</tt> hash to translate OpenDocument's
	#	<tt>style:num-format</tt> to the corresponding CSS
	#	<tt>list-style-type</tt>.
	#
	def process_text_list_style( element )
		marker = ["circle", "disc", "square"];
		numbering = {"1" => "decimal",
			"a" => "lower-alpha", "A" => "upper-alpha",
			"i" => "lower-roman", "I" => "upper-roman" }

		main_name = element.attribute( "#{@style_ns}:name" ).value
		element.elements.each do |child|
			level = child.attribute("#{@text_ns}:level").value
			selector = main_name + "_" + level

			if (child.name == "list-level-style-bullet")
				process_normal_style_attr( selector, "list-style-type",
					marker[(level.to_i-1)%3] )
			elsif (child.name == "list-level-style-number")
				process_normal_style_attr( selector, "list-style-type",
					numbering[child.attribute("#{@style_ns}:num-format").value] )
			end
		end
	end

	#
	#	Emit an element with the given <tt>element_name</tt> and
	#	<tt>attr_hash</tt> (as attributes) as a child of the
	#	<tt>output_node</tt>
	def emit_element( output_node, element_name, attr_hash=nil )
		if (attr_hash != nil) then
			attr_hash.each do |key, value|
				if (value == nil) then
					attr_hash.delete( key )
				end
			end
			if attr_hash.empty? then
				attr_hash = nil
			end
		end
		output_node.add_element( element_name, attr_hash )
	end
	
	#
	#	Modify the style attribute of <tt>output_element</tt> by adding
	#	the given <tt>property</tt> and <tt>value</tt>
	#
	#	Algorithm:
	#		If there's no style attribute, create it.
	#		If it exists, look for the property.
	#			If the property doesn't exist, add it and its value
	#			If it does exist, 
	def modify_style_attribute( output_element, property, value )
		current = output_element.attribute("style")
		new_value = (current != nil) ? current.value + ";" : ""
		new_value += "#{property}:#{value}"
		output_element.attributes["style"] = new_value
	end
end

