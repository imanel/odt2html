require 'spec_helper'

describe "files" do
  it "should read ODT file and generate matching HTML file" do
    odt_path = File.join(File.dirname(__FILE__), *%w[.. fixtures example.odt])
    html_path = File.join(File.dirname(__FILE__), *%w[.. fixtures example.html])
    html_file = File.open(html_path)
    tempfile = Tempfile.new('html')

    begin
      parser = ODT2HTML::Base.new
      parser.instance_variable_set('@input_filename', odt_path)
      parser.instance_variable_set('@output_filename', tempfile.path)

      parser.convert

      tempfile.rewind
      tempfile.read.should eql(html_file.read)
    ensure
      tempfile.close!
    end
  end
end