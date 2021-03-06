#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require "rubygems"

begin
 require "bundler"
rescue LoadError => e
  $stderr.puts "No Bundler. Use system gem."
else
  Bundler.setup
end

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/auto-reload' if development?
require 'sinatra/static_assets'
require 'sinatra/content_for'
require 'rack'
require 'erb'
require 'json'
require 'uri'
require 'tokyocabinet'
include TokyoCabinet

def auto_reload_ignores
  [/db.*/, /config.yaml/]
end

@@dbdir = 'db'

def db_open(dbname='/')
  dbname = dbname.to_s.gsub(/\//, '_')
  @pages = HDB.new
  Dir.mkdir(@@dbdir) if !File.exists?(@@dbdir)
  Dir.mkdir("#{@@dbdir}/pages") if !File.exists?("#{@@dbdir}/pages")
  @pages.open("#{@@dbdir}/pages/_#{dbname}.tch", HDB::OWRITER|HDB::OCREAT)  
end

def sub_pages(current_page='/')
  pattern = "#{@@dbdir}/pages/"+"#{current_page.to_s}".gsub(/\//, '_')+"*.tch"
  Dir.glob(pattern).map{|i|
    esc = "#{current_page.to_s}".gsub(/\//, '_')
    i.scan(/#{@@dbdir}\/pages\/#{esc}(.+)\.tch/).first.to_s.gsub(/_/,'/')
  }.delete_if{|i| i.size < 1 }
end

before do
  @title = "gyaazz"
end

after do
  @pages.close if @pages
end

get '/' do
  @sub_pages = sub_pages
  erb :search
end

get '/api/*/.json' do
  {'search' => 'constructing'}.to_json
end

get '/api/*.json' do
  db_open(params[:splat])
  if @pages.keys.size < 1
    @mes = {'lines' => ["(empty)"]}.to_json
  else
    if params[:v]
      ver = params[:v].to_i
      key = @pages.keys.reverse[ver]
    else
      key = @pages.keys.last
    end
    @mes = @pages[key]
  end
end

get '/api/*' do
  redirect env['REQUEST_URI'].gsub(/\/api\//, "/API/")
end

get '/*/' do
  @sub_pages = sub_pages(URI.decode env['PATH_INFO'])
  @title = params[:splat].to_s
  erb :search
end

get '/*' do
  p params[:splat]
  @title = params[:splat].to_s
  erb :edit
end

post '/api/*.json' do
  begin
    db_open(params[:splat])
    lines = params[:lines].delete_if{|i| i.size < 1 or i=~/^\s+$/}
    last_key = @pages.keys.last
    if last_key and JSON.parse(@pages[last_key])['lines'] == lines
      @mes = {'success' => true, 'message' => 'save'}.to_json
    else
      now = Time.now
      key = "#{now.to_i}_#{now.usec}"
      @pages[key] = {'lines' => lines}.to_json
      if lines.size < 2 and lines.first == "(empty)"
        # ページの削除処理
        @mes = {'success' => true, 'message' => 'delete page'}.to_json
      else
        @mes = {'success' => true, 'message' => 'saved!'}.to_json
      end
    end
  rescue
    @mes = {'error' => true, 'message' => 'save error!'}.to_json
  end
end
