module ODT2HTML
  class Base
    include AnalyzeContent
    include AnalyzeGraphics
    include AnalyzeStyles

    def initialize( )

      @@debug = 0

      @doc = nil
      @input_filename = nil

      @output_filename = nil
      @output_doc = nil

      @head = nil
      @body = nil

      @css_filename = nil

      @image_dir = nil

      @namespace_urn = {
        "urn:oasis:names:tc:opendocument:xmlns:office:1.0"=>"office",
        "urn:oasis:names:tc:opendocument:xmlns:style:1.0"=>"style",
        "urn:oasis:names:tc:opendocument:xmlns:text:1.0"=>"text",
        "urn:oasis:names:tc:opendocument:xmlns:table:1.0"=>"table",
        "urn:oasis:names:tc:opendocument:xmlns:drawing:1.0"=>"draw",
        "urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"=>"fo",
        "http://www.w3.org/1999/xlink"=>"xlink",
        "http://purl.org/dc/elements/1.1/"=>"dc",
        "urn:oasis:names:tc:opendocument:xmlns:meta:1.0"=>"meta",
        "urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0"=>"number",
        "urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"=>"svg",
        "urn:oasis:names:tc:opendocument:xmlns:chart:1.0"=>"chart",
        "urn:oasis:names:tc:opendocument:xmlns:dr3d:1.0"=>"dr3d",
        "http://www.w3.org/1998/Math/MathML"=>"math",
        "urn:oasis:names:tc:opendocument:xmlns:form:1.0"=>"form",
        "urn:oasis:names:tc:opendocument:xmlns:script:1.0"=>"script",
        "http://openoffice.org/2004/office"=>"ooo",
        "http://openoffice.org/2004/writer"=>"ooow",
        "http://openoffice.org/2004/calc"=>"oooc",
        "http://www.w3.org/2001/xml-events"=>"dom"
      }

      #
      # These are the "canonical forms" of the styles we want to process.
      # when we get the namespaces, we'll push them into the @style_dispatch
      # hash. If a style name ends with a *, the next entry is the name of
      # a method that handles that entry. Otherwise, process_normal_style_attr
      # gets put into @style_dispatch
      #
      @valid_style = %w(
        style:font-name* process_font_name
        fo:color
        fo:background-color
        fo:font-size
        fo:font-style
        fo:font-weight
        fo:margin-top
        fo:margin-right
        fo:margin-bottom
        fo:margin-left
        fo:margin
        fo:padding-top fo:padding-right fo:padding-bottom fo:padding-left
        fo:padding
        fo:border-top fo:border-right fo:border-bottom fo:border-left
        fo:border
        fo:text-align* process_text_align
        fo:text-indent
        style:column-width* process_column_width
        style:text-underline-style* process_underline_style
        style:text-position* process_style_text_position
      )

      # The style dispatch hash's key is a style name;
      # the value is the name of the function to call to
      # process that style.
      @style_dispatch = Hash.new

      # The keys for <tt>@nshash</tt> are canonical namespace names;
      # the values are the actual namespace prefixes used in the
      # document being processed.
      @nshash = Hash.new

      # The <tt>@style_info</tt> hash gives a style name as its key;
      # the value is a <tt>DeclarationBlock</tt>. When a style is
      # actually used in the document, we set the style's
      # <tt>@block_used</tt> property to <tt>true</tt>.
      #
      @style_info = Hash.new

      #
      # Paragraphs merge borders by default; this means we
      # must remember the last paragraph style emitted
      # and a reference to the paragraph
      @previous_para_style = nil
      @previous_para = nil
    end

    #
    # Establish a mapping between "standard" namespaces (in @namespace_urn)
    # and namespace prefixes used in the document at hand.
    #
    # This code dynamically creates instance variables for the namespaces
    # with "_ns" added to the variable name to avoid collisions.
    # It is also added to the namespace hash <tt>@nshash</tt>
    #
    # The technique comes from a post to comp.lang.ruby by Guy Decoux
    #
    def get_namespaces
      @nshash.clear
      root_element = @doc.root
      root_element.attributes.each_attribute do |attr|
        if @namespace_urn.has_key?( attr.value ) then
          @nshash[@namespace_urn[attr.value]] = attr.name
          self.class.send(:attr_accessor, @namespace_urn[attr.value] + "_ns")
          send("#{@namespace_urn[attr.value]+'_ns'}=", attr.name)
        end
      end
    end

    def get_options
      opts = GetoptLong.new(
        ["--in", GetoptLong::REQUIRED_ARGUMENT],
        ["--out", GetoptLong::OPTIONAL_ARGUMENT],
        ["--css", GetoptLong::REQUIRED_ARGUMENT],
        ["--images", GetoptLong::REQUIRED_ARGUMENT]
      )
      opts.each do |opt, arg|
        case opt
          when "--in"
            @input_filename = arg
          when "--out"
            @output_filename = arg
          when "--css"
            @css_filename = arg
          when "--images"
            @image_dir = arg
        end
      end
    end

    def get_xml( member_name )
      zipfile = Zip::ZipFile::open( @input_filename )
      stream = zipfile.get_entry( member_name ).get_input_stream
      doc = REXML::Document.new stream.read
      zipfile.close
      return doc
    end

    def add_xhtml_head_info
      @head.add_element("meta",
        "http-equiv"=>"content-type", "content"=>"text/html; charset=utf-8")
      @head.add_element("title").add_text( @input_filename )
    end

    def collect_styles
      str = ""
      @style_info.keys.sort.each do |style|
        if (@style_info[style].length > 0 && yield(@style_info[style])) then
          str << style_to_s(style) << "\n"
        end
      end
      return str
    end

    def convert
      get_options

      if (@input_filename == nil)
        usage
        raise ArgumentError, "No input file name given"
      end

      # if (@output_filename == nil)
      #   usage
      #   raise ArgumentError, "No output file name given"
      # end


      if (@image_dir != nil)
        if (!File.exist?(@image_dir))
          Dir.mkdir(@image_dir)
        end
      end

      str = <<HDR
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
   "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<!-- Produced by ODF to XHTML converter, #{Time.now} -->

<html>
</html>
HDR
      @output_doc = REXML::Document.new str
      @head = @output_doc.root.add_element("head")
      @body = @output_doc.root.add_element("body")
      add_xhtml_head_info

      @doc = get_xml("styles.xml")
      analyze_styles_xml

      @doc = get_xml("content.xml")
      analyze_content_xml

      all_styles = collect_styles { |item| item.block_used }

      if (@css_filename != nil) then
        css_file = File.open( @css_filename, "w" )
        @head.add_element("link",
          {"rel" => "stylesheet", "type" => "text/css",
          "href" => @css_filename} )
        css_file.puts(all_styles)
      else
        style_el = @head.add_element("style", {"type" => "text/css"} )
        style_el.add_text( all_styles )
      end

      if (@output_filename) then
        output_file = File.open( @output_filename, "w")
      else
        output_file = $stdout
      end

      @output_doc.write( output_file, 4 )
      output_file.close

      rescue Exception => e
        puts "Cannot convert file: #{e}"
        puts e.backtrace.join("\n")
    end

    def usage
      puts "Usage: #{$0} --in inputfile --out outputfile [--css cssfile] [--images imagedir]"
    end

  end
end