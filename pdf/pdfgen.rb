#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'yaml'
require 'redcarpet'
require './generate_index'

class String
	def del!(regex)
		gsub!(regex, '')
	end
end

$dont_render = ['release-notes.md']

markdown_toc_parser = Redcarpet::Markdown.new(Redcarpet::Render::HTML_TOC.new(),
	:fenced_code_blocks => true,
  :autolink => true,
  :no_intra_emphasis => true,
  :space_after_headers => false
)

markdown_parser = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(),
  :fenced_code_blocks => true,
  :autolink => true,
  :no_intra_emphasis => true,
  :space_after_headers => false
)

$html_string = ""
$toc_string = ""

dirs_to_render = ['dev', 'ops', 'theory']

Dir['source/languages/en/riak/**/*.md'].each do |file|
	if !($dont_render.include? file)
		raw_file_contents = File.read(file)
		raw_file_contents.gsub!(/\/images/, 'source/images')
		$html_string << markdown_parser.render(raw_file_contents)
		$toc_string << markdown_parser.render(raw_file_contents)
	end
end

html = $html_string

final_string = """<html>
  <head>
    <title>The Riak Documentation</title>
  </head>
  <body>
    #{html}
  </body>
</html>"

File.write('docs.html', final_string)

def generate_index_markdown
  markdown_string = String.new
  markdown_string.concat("Welcome to the Riak Docs!\n\n")
  riak_nav = YAML.load_file('source/languages/en/global_nav.yml')['riak']
  Array(0..riak_nav.length - 1).each do |section|
    markdown_string.concat("## #{riak_nav[section]['title']}\n\n")
    
  end
  p markdown_string
  File.write('index.md', markdown_string)
end
generate_index_markdown