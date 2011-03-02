require 'rexml/document'
require 'rexml/xpath'

class ODT_to_XHTML

  def process_draw_frame( element, output_node )
    style_name = register_style( element );
    div = emit_element( output_node, "div", {"class" => style_name} )
    attr = element.attribute("#{@svg_ns}:width")
    if (attr != nil) then
      modify_style_attribute( div, "width", attr.value )
    end
    attr = element.attribute("#{@svg_ns}:height")
    if (attr != nil) then
      modify_style_attribute( div, "height", attr.value )
    end
    process_children( element, div )
  end

  #
  # Copy an image into user-specified directory, and emit
  # a corresponding <tt>&lt;img&gt;</tt> element.
  #
  # If the user has not specified an image directory,
  # then emit a <tt>&lt;div&gt;</tt> containing the
  # file name.
  def process_draw_image( element, output_node )
    pic_name = element.attribute("#{@xlink_ns}:href").value
    if (@image_dir != nil) then
      img = emit_element( output_node, "img" )
      img.attributes["alt"] = pic_name

      # Get rid of everything before the last / in the filename
      base_name = pic_name;
      if ((pos = base_name.rindex('/')) != nil) then
        base_name = base_name[pos + 1 .. -1]
      end
      copy_image_file( pic_name, @image_dir, base_name )
      img.attributes["src"] = "#{@image_dir}/#{base_name}"
      width = element.parent.attribute("#{@svg_ns}:width")
      height= element.parent.attribute("#{@svg_ns}:height")
      if (width != nil && height != nil) then
        img.attributes["style"] = "width:#{width.value}; " +
          "height:#{height.value}"
      end
    else
      div = emit_element( output_node, "div" )
      div.add_text( pic_name )
    end
  end

  def copy_image_file( pic_name, directory, filename )
    zipfile = Zip::ZipFile::open( @input_filename )
    inStream = zipfile.get_entry( pic_name )
    if (inStream != nil) then
      inStream = inStream.get_input_stream
      outStream =  File.new("#{directory}#{File::SEPARATOR}#{filename}", "w")
      outStream.binmode
      buf =  inStream.read
      outStream.print buf
      outStream.close
      inStream.close
    end
    zipfile.close
    rescue Exception => e
      #
      # Uncomment next line if you want error output
      # $stderr.puts "Could not find image #{pic_name}"
  end
end

