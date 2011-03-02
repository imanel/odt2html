require 'rexml/document'
require 'rexml/xpath'
require 'zip/zip'
require 'stringio'
require 'getoptlong'

module ODT2HTML

  VERSION = "0.1.0"
  ROOT_PATH = File.expand_path(File.dirname(__FILE__))

  autoload :Base,             "#{ROOT_PATH}/odt2html/base"
  autoload :AnalyzeContent,   "#{ROOT_PATH}/odt2html/analyze_content"
  autoload :AnalyzeGraphics,  "#{ROOT_PATH}/odt2html/analyze_graphics"
  autoload :AnalyzeStyles,    "#{ROOT_PATH}/odt2html/analyze_styles"
  autoload :Declaration,      "#{ROOT_PATH}/odt2html/declaration"
  autoload :DeclarationBlock, "#{ROOT_PATH}/odt2html/declaration_block"

end

class REXML::Element
  def attribute_value( name, namespace=nil )
    attr = attribute( name, namespace )
  return (attr != nil) ? attr.value : nil
  end
end