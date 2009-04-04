#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'sinatra'
require 'yaml'
require 'redcloth'
require 'dm-core'

BASE_DIR = File.expand_path(File.dirname(__FILE__))
SETTING = YAML.load(open("#{BASE_DIR}/setting.yml"))
set SETTING
set :views, "#{BASE_DIR}/themes/#{SETTING['theme']}"

enable :sessions

configure :test do
  DataMapper.setup(:default, "sqlite3::memory:")
end

configure :development do
  set :app_file, __FILE__
  set :reload, true
  DataMapper.setup(:default, "sqlite3:///#{BASE_DIR}/development.db")
end

configure :production do
  DataMapper.setup(:default, "sqlite3:///#{BASE_DIR}/production.db")
end

configure do
  require 'models'
  DataMapper.auto_upgrade!
end

SETTING['plugins'].each do |plugin|
  begin
    load "#{BASE_DIR}/plugins/#{plugin}.rb"
    puts 'Load plugin => ' + plugin
  rescue Exception => e
    puts "Error: #{e}"
    puts e.backtrace.join("\n")
  end
end

before do
  AuthToken.delete_old_tokens
  @logged_in = false
  auth_token = AuthToken.first(:token => session['token'])
  if auth_token
    auth_token.expired_at = token_expired_time
    auth_token.save
    @logged_in = true
  end
  content_type "text/html", :charset => "utf-8"
end

get '/' do
  @page = 1
  @entries = Entry.all(:order => [:id.desc], :limit=>options.par_page)
  count = repository(:default).adapter.query('SELECT count(*) FROM entries')[0]
  @page_count = (count / options.par_page.to_f).ceil
  haml "= partial 'entries', :locals => {:entries => @entries}"
end

get '/page/:page' do
  if params[:page] =~ /\d+/
    @page = params[:page].to_i
    @entries = Entry.all(:order => [:id.desc], :limit => options.par_page, :offset => (@page - 1) * options.par_page)
    count = repository(:default).adapter.query('SELECT count(*) FROM entries')[0]
    @page_count = (count / options.par_page.to_f).ceil
    haml "=partial 'entries', :locals => {:entries => @entries}"
  else
    redirect '/'
  end
end

get '/search' do
  @q = params[:q] || ''
  @page = 
    if params[:page] && params[:page] =~ /\d+/
      params[:page].to_i
    else
      1
    end
  unless @q.empty?
    @entries = repository(:default).adapter.query(
      'SELECT * FROM entries WHERE title like ? or body like ? limit ? offset ?',
      "%#{@q}%", "%#{@q}%", options.par_page, (@page - 1) * options.par_page)
    count = repository(:default).adapter.query(
      'SELECT count(*) FROM entries WHERE title like ? or body like ?',
      "%#{@q}%", "%#{@q}%")[0]
    @page_count = (count / options.par_page.to_f).ceil
    haml "= partial 'search', :locals => {:entries => @entries}"
  else
    redirect '/'
  end
end

get '/entry/edit/:id' do
  if @logged_in
    @entry = Entry.get(params[:id])
    haml "= partial 'entry/form', :locals => {:action => '/entry/update/#{params[:id]}', :button_label => 'save'}"
  end
end

post '/entry/update/:id' do
  if @logged_in
    @entry = Entry.get(params[:id])
    @entry.update_attributes(:title=>params[:title], :body=>params[:body])
    redirect "/entry/#{@entry.id}"
  end
end

post '/entry/delete/:id' do
  if @logged_in
    @entry = Entry.get(params[:id])
    @entry.destroy
    redirect "/"
  end
end

get '/entry/new' do
  if @logged_in
    @entry = Entry.new
    haml "= partial 'entry/form', :locals => {:action=>'/entry/create', :button_label=>'post'}"
  end
end

post '/entry/create' do
  if @logged_in
    e = Entry.create(params)
    redirect "/entry/#{e.id}"
  end
end

get '/entry/:id' do
  @entry = Entry.get(params[:id])
  if @entry
    haml "= partial 'entry/entry', :locals => {:entry => @entry}"
  else
    redirect "/"
  end
end

get '/login' do
  if @logged_in
    redirect '/'
  else
    haml :login
  end
end

post '/login' do
  if @logged_in
    redirect '/'
  elsif auth(params[:user_id], params[:password])
    auth_token = AuthToken.new(:token=>AuthToken.generate_token, :expired_at=>token_expired_time)
    session['token'] = auth_token.token
    auth_token.save
    redirect '/'
  else
    redirect '/error'
  end
end

get '/logout' do
  auth_token = AuthToken.first(:token => session['token'])
  if auth_token
    auth_token.destroy
  end
  redirect '/'
end

get '/css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :styles
end

helpers do
  def auth?
    @logged_in
  end

  def h(text)
    Rack::Utils.escape_html(text)
  end

  def tx(str)
    if str
      RedCloth.new(str).to_html
    else
      ''
    end
  end

  def partial(template, options = {})
    options = options.merge({:layout => false})
    template = "#{template.to_s}".to_sym
    haml(template, options)
  end
end

def token_expired_time
  DateTime.now + 60 * 60 * 24
end

def auth(user_id, password)
  options.user_id == user_id && options.password == password
end

